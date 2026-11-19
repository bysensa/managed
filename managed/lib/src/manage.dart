library managed;

import 'dart:async';

import 'package:meta/meta.dart';

part 'lifecycle.dart';
part 'scope.dart';

typedef Factory<T> = T Function();
typedef ManagedBy = Set<Manage>;
typedef OnNewInstance<T> = void Function(T);
typedef OnDispose<T> = FutureOr<void> Function(T);

/// Values that generated [Params] pass to a factory through its zone.
/// Exported for generated code by `package:managed/codegen.dart`.
typedef ZoneValues = Map<Object?, Object?>;

/// Call arguments of a generated registration.
/// Exported for generated code by `package:managed/codegen.dart`.
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

/// Same as [Manage.resolve].
I resolve<I extends Object>([Object? resolutionKey]) =>
    Manage.resolve<I>(resolutionKey);

/// A callable registration for [T]. Top-level or static fields let modules
/// refer to the same registration and its lifetime from anywhere in the app.
class Manage<T extends Object> with Provider<T> {
  /// Returns the input of type [I] of the factory that is being built.
  /// A [resolutionKey] selects the input registered with that key, e.g. when
  /// several inputs share the type [I].
  static I resolve<I extends Object>([Object? resolutionKey]) {
    final invocationZone = Zone.current;
    _Resolution.current?.check();
    final key = resolutionKey == null ? I : (I, resolutionKey);
    final dependencyInstance = invocationZone[key];
    if (dependencyInstance is I) {
      return dependencyInstance;
    }
    if (resolutionKey != null) {
      throw StateError(
        'Instance of type $I with resolution key $resolutionKey is not '
        'provided. Check that Manage.dependsOn contains a Manage<$I> '
        'registered with this resolutionKey',
      );
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
  late final Object _cacheKey = _dependencies.isEmpty && resolutionKey == null
      ? _factory
      : _FactoryBinding(_factory, _dependencies, resolutionKey);

  List<Manage> get dependencies => _dependencies;

  /// Lets a consumer select this input with `resolve<T>(resolutionKey)`.
  /// Any object works, e.g. an enum value, a module type or a string.
  final Object? resolutionKey;

  /// [dependsOn] supplies factory inputs and propagates invalidation.
  /// [onDispose] releases a managed instance before its inputs are released.
  Manage(
    this._factory, {
    this.scope = ScopeType.unique,
    List<Manage>? dependsOn,
    OnNewInstance<T>? onNewInstance,
    OnDispose<T>? onDispose,
    this.resolutionKey,
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

  /// A cleanup releases consumers before their inputs. While it runs, a
  /// disposer receives an input that is still alive instead of a new instance
  /// built for the next state. An already released consumer is an error.
  T? _instanceInRelease() {
    final cache = _storage._instances;
    final batch = Zone.current[_Lifetime._releasing] as Set<_Entry>?;
    if (cache == null || batch == null) return null;
    _Entry? released;
    for (final entry in batch) {
      if (!identical(entry.cache, cache) || entry.cacheKey != _cacheKey) {
        continue;
      }
      if (!entry._released) return entry.value as T;
      released = entry;
    }
    if (released != null) {
      throw StateError('$T was already released by the current cleanup.');
    }
    return null;
  }

  /// Returns the instance, constructing its dependencies on a cache miss.
  @override
  T call() => _call(null);

  T _call(Params? params) {
    _Resolution.current?.check();
    if (_mock != null) return _read(_mock!);
    final releasing = _instanceInRelease();
    if (releasing != null) return releasing;
    if (_storage._instances?.containsKey(_cacheKey) ?? false) return _provide();
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
        final instance =
            argument is Params ? dependency._call(argument) : dependency();
        values[dependency.managedType] = instance;
        final resolutionKey = dependency.resolutionKey;
        if (resolutionKey != null) {
          values[(dependency.managedType, resolutionKey)] = instance;
        }
      }
      resolution.check();
      return runZoned(_provide, zoneValues: values);
    });
  }

  T _provide() {
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

/// Calls a registration with the [Params] of a generated binding. Without
/// params, the registration's own [Manage.call] applies its defaults, so an
/// override of [Manage.call] must pass non-null params here.
/// Exported for generated code by `package:managed/codegen.dart`.
extension GeneratedCall<T extends Object> on Manage<T> {
  T callWithParams(Params? params) => params == null ? call() : _call(params);
}

extension ManageExt<T extends Object> on Manage<T> {
  Manage<S> as<S extends Object>() {
    // The factory may return a subtype of T, so check the registration itself.
    if (this is Manage<S>) return AsManage._(this as Manage<S>);
    throw StateError('Type $T cant be treated as $S');
  }
}

class AsManage<S extends Object> extends Manage<S> {
  AsManage._(this._delegate)
      : super(_delegate._factory,
            scope: _delegate.scope,
            dependsOn: _delegate.dependencies,
            resolutionKey: _delegate.resolutionKey);

  final Manage<S> _delegate;

  @override
  Manage get _canonical => _delegate._canonical;

  @override
  S call() => _delegate.call();

  @override
  S _call(Params? params) =>
      params == null ? _delegate.call() : _delegate._call(params);

  @override
  S _provide() => _delegate._provide();

  @override
  Future<void> mock(S instance) =>
      throw UnsupportedError('Mock the original registration.');

  @override
  Future<void> resetMock() => _delegate.resetMock();
}
