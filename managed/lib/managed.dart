library managed;

import 'dart:async';

import 'package:meta/meta.dart';

part 'src/lifecycle.dart';
part 'src/scope.dart';

typedef Factory<T> = T Function();
typedef ManagedBy = Set<Manage>;
typedef OnNewInstance<T> = void Function(T);
typedef OnDispose<T> = FutureOr<void> Function(T);
typedef ZoneValues = Map<Object?, Object?>;

abstract class Params {
  Type get targetType;

  void inject(ZoneValues values, Map<Type, Manage> dependencies);
}

enum ScopeType {
  unique,
  cached,
  singleton,
}

mixin Provider<T extends Object> {
  T call();
}

Type nonNullableTypeOf<T>(T? object) => T;

/// A callable registration for [T]. Top-level or static fields let modules
/// refer to the same registration and its lifetime from anywhere in the app.
class Manage<T extends Object> with Provider<T> {
  static I resolve<I>() {
    final invocationZone = Zone.current;
    _Resolution.current?.check();
    final dependencyInstance = invocationZone[I];
    if (dependencyInstance is I) {
      return dependencyInstance;
    }
    throw StateError(
      'Instance of type $I is not provided. '
      'Check that Manage.dependsOn contains variable of Manage<$I>',
    );
  }

  Type get managedType => T;

  /// Controls how instances of [T] are reused.
  final ScopeType scope;

  final Factory<T> _factory;

  final OnNewInstance<T>? _onNewInstance;
  final OnDispose<T>? _onDispose;
  _Lifetime? _overrideChanges;
  Expando<_InstanceChanges>? _notifications;

  _InstanceChanges _changesFor(DependencyLifecycle value) {
    final notifications = _notifications ??= Expando<_InstanceChanges>();
    return notifications[value] ??= _InstanceChanges(this);
  }

  Future<void> _dependencyChanged(DependencyLifecycle value) =>
      _changesFor(value).invalidate();

  T? _mock;

  final List<Manage> _dependencies;
  late final Object _cacheKey = _dependencies.isEmpty
      ? _factory
      : _FactoryBinding(_factory, _dependencies);

  List<Manage> get dependencies => _dependencies;

  /// [dependsOn] supplies factory inputs and propagates invalidation.
  /// [onDispose] releases a managed instance before its inputs are released.
  Manage(
    this._factory, {
    this.scope = ScopeType.unique,
    List<Manage>? dependsOn,
    OnNewInstance<T>? onNewInstance,
    OnDispose<T>? onDispose,
  })  : _onNewInstance = onNewInstance,
        _onDispose = onDispose,
        _dependencies = List.unmodifiable(dependsOn ?? const []);

  _InstanceScope get _storage {
    return switch (scope) {
      ScopeType.unique => Scope._unique,
      ScopeType.cached => Scope._cached,
      ScopeType.singleton => Scope._singleton,
    };
  }

  Manage get _canonical => this;

  void _collectLifetimes(Set<_Lifetime> result, Set<Manage> visited) {
    if (!visited.add(this)) return;
    final entry = _storage._instances?[_cacheKey];
    if (entry != null) {
      result.addAll(entry.lifetimes);
      return;
    }
    final reset = _storage._reset;
    if (reset != null) result.add(reset);
    for (final dependency in _dependencies) {
      final provider = dependency._canonical;
      result
          .add(provider._overrideChanges ??= _Lifetime(ownsTransients: false));
      if (provider._mock == null) provider._collectLifetimes(result, visited);
    }
  }

  _Resolution _resolution() {
    final lifetimes = <_Lifetime>{};
    _collectLifetimes(lifetimes, {});
    // A transient created for a managed consumer belongs to its lifetime.
    final parent = _Resolution.current;
    final inherits =
        scope == ScopeType.unique && parent != null && parent.building;
    if (inherits) lifetimes.addAll(parent.generations.keys);
    return _Resolution(this, lifetimes,
        scope != ScopeType.unique || (inherits && parent.ownsTransients));
  }

  T _read(T value, [_Entry? entry]) {
    _InstanceChanges? changes;
    if (value is DependencyLifecycle) {
      changes = entry == null
          ? value._attach(this)
          : entry._changes ??= value._attach(this);
    }
    _Resolution.current?.observe(this, entry?.lifetimes ?? const [], changes);
    return value;
  }

  /// Returns the instance, constructing its dependencies on a cache miss.
  @override
  T call([covariant Params? params]) {
    _Resolution.current?.check();
    if (_mock != null) return _read(_mock!);
    if (_storage._instances?.containsKey(_cacheKey) ?? false) return provide();
    final resolution = _resolution();
    return resolution.run(() {
      final ZoneValues values = {};
      Iterable<Manage> remaining = _dependencies;
      if (params != null) {
        final byType = {for (final dep in _dependencies) dep.managedType: dep};
        params.inject(values, byType);
        remaining = byType.values;
      }
      for (final dependency in remaining) {
        final argument = Zone.current[dependency.managedType];
        values[dependency.managedType] =
            dependency(argument is Params ? argument : null);
      }
      resolution.check();
      return runZoned(provide, zoneValues: values);
    });
  }

  @protected
  T callForGenerated() {
    _Resolution.current?.check();
    if (_mock != null) {
      return _read(_mock!);
    }
    return provide();
  }

  @protected
  T provide() {
    final current = _Resolution.current;
    current?.check();
    final entry = _storage._instances?[_cacheKey];
    if (entry != null) return _read(entry.value as T, entry);
    final resolution =
        identical(current?.provider, this) ? current! : _resolution();
    return resolution.run(() => _storage._create(
          _cacheKey,
          _factory,
          resolution.ownsTransients ? resolution.generations.keys.toSet() : {},
          _onNewInstance,
          _onDispose,
          resolution: resolution,
        ));
  }

  /// Overrides this registration and invalidates consumers of its previous value.
  @visibleForTesting
  Future<void> mock(T instance) {
    if (identical(_mock, instance)) return Future.value();
    _mock = instance;
    return _overrideChanges?.invalidate() ?? Future.value();
  }

  /// Removes a test override and invalidates consumers of the mock.
  @visibleForTesting
  Future<void> resetMock() {
    if (_mock == null) return Future.value();
    _mock = null;
    return _overrideChanges?.invalidate() ?? Future.value();
  }
}

extension ManageExt<T extends Object> on Manage<T> {
  Manage<S> as<S extends Object>() {
    final factory = _factory;
    if (factory is Factory<S>) {
      return AsManage._(this as Manage<S>);
    }

    throw StateError('Type $T cant be treated as $S');
  }
}

class AsManage<S extends Object> extends Manage<S> {
  AsManage._(this._delegate)
      : super(_delegate._factory,
            scope: _delegate.scope, dependsOn: _delegate.dependencies);

  final Manage<S> _delegate;

  @override
  Manage get _canonical => _delegate._canonical;

  @override
  S call([covariant Params? params]) => _delegate.call(params);

  @override
  S provide() => _delegate.provide();

  @override
  S callForGenerated() => _delegate.callForGenerated();

  @override
  Future<void> mock(S instance) =>
      throw UnsupportedError('Mock the original registration.');

  @override
  Future<void> resetMock() => _delegate.resetMock();
}
