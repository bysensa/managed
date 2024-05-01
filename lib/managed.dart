library managed;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

typedef Factory<T> = T Function();
typedef ManagedBy = Set<Manage>;
typedef OnNewInstance<T> = void Function(T);
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

/// Class used to register specific Type and instance factory for it. This class
/// must be used together with static variable. Instance of this class should be created
/// only once for concrete type [T].
class Manage<T extends Object> with Provider<T> {
  static I resolve<I>() {
    final invocationZone = Zone.current;
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

  /// scope where instances of [T] is stored
  final ScopeType scope;

  /// Factory which provide instances of type [T]
  final Factory<T> _factory;

  final OnNewInstance<T>? _onNewInstance;

  /// This variable used in test when we want to mock type [T] with out changing
  /// behaviour of dependency injection
  T? _mock;

  final List<Manage> _dependencies;

  List<Manage> get dependencies => UnmodifiableListView(_dependencies);

  Manage(
    this._factory, {
    this.scope = ScopeType.unique,
    List<Manage>? dependsOn,
    OnNewInstance<T>? onNewInstance,
  })  : _onNewInstance = onNewInstance,
        _dependencies = dependsOn ?? [];

  Scope _resolveScope() {
    return switch (scope) {
      ScopeType.unique => Scope.unique,
      ScopeType.cached => Scope.cached,
      ScopeType.singleton => Scope.singleton,
    };
  }

  /// Returns instance of type [T]
  ///
  /// If mock is provided using [mock] method when instance from [_mock] variable
  /// will be returned else we receive instance from [_scope].
  @override
  T call([covariant Params? params]) {
    if (_mock != null) {
      return _mock!;
    }
    final zone = Zone.current;
    return zone.fork(
      zoneValues: {
        for (final dependency in _dependencies)
          dependency.managedType: dependency(zone[dependency.managedType]),
      },
    ).run(provide);
  }

  @protected
  T callForGenerated() {
    if (_mock != null) {
      return _mock!;
    }
    return provide();
  }

  @protected
  T provide() {
    final _scope = _resolveScope();
    return _scope.provideUsing(
      _factory,
      onNewInstance: (instance) {
        if (instance is T) {
          _onNewInstance?.call(instance);
        }
      },
    );
  }

  /// Register mock instance which can be used in tests
  ///
  /// This method must be used in tests only
  @visibleForTesting
  void mock(T instance) {
    _mock = instance;
  }

  /// Drop previously provided mock instance.
  ///
  /// This method must be used in tests only
  @visibleForTesting
  void resetMock() {
    _mock = null;
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

class AsManage<S extends Object> implements Manage<S> {
  AsManage._(this._delegate);

  final Manage<S> _delegate;

  @override
  S? get _mock {
    return _delegate._mock;
  }

  @override
  set _mock(S? newValue) {
    throw UnsupportedError('message');
  }

  Scope _resolveScope() {
    return _delegate._resolveScope();
  }

  @override
  List<Manage<Object>> get _dependencies => _delegate._dependencies;

  @override
  Factory<S> get _factory => _delegate._factory;

  @override
  OnNewInstance<S>? get _onNewInstance => null;

  @override
  ScopeType get scope => _delegate.scope;

  @override
  S call([covariant Params? params]) {
    return _delegate.call(params);
  }

  S provide() {
    return _delegate.provide();
  }

  @override
  Type get managedType => S;

  @override
  void mock(S instance) {
    _mock = instance;
  }

  @override
  void resetMock() {
    _delegate.resetMock();
  }

  @override
  List<Manage<Object>> get dependencies => _delegate.dependencies;

  @override
  S callForGenerated() {
    return _delegate.callForGenerated();
  }
}

/// This class used to store instances of dependencies.
///
/// There are 3 different implementation of [Scope] provided out of the box.
/// The [unique] implementation provide new instance every time. The [singleton]
/// implementation provide new instance of specific type only once. The [cached]
/// implementation provide same instance of specific type while not reset.
abstract class Scope {
  static final Scope unique = _UniqueScope();
  static final Scope singleton = _SingletonScope();
  static final Scope cached = _CachedScope();

  /// Returns instance created using [factory]
  ///
  /// For [unique] implementation call to this method just invoke provided [factory]
  /// and return instance created by this factory. For [singleton] implementation
  /// call to this method will check there are no instances created by this [factory].
  /// If so then new instance will be created using this [factory] and stored in internal map.
  /// Created instance will be returned. Else, previously created instance will be returned.
  /// For [cached] implementation the behaviour is similar to [singleton] implementation.
  /// The main difference is that the [cached] implementation internal map can be cleared.
  dynamic provideUsing(Factory factory, {OnNewInstance? onNewInstance});

  /// Drop previously created instances
  ///
  /// For [unique] and [singleton] implementation call of this method has no effect.
  /// For [cached] implementation its trigger drop of previously created instances.
  void reset();
}

class _UniqueScope implements Scope {
  @override
  dynamic provideUsing(
    Factory factory, {
    OnNewInstance? onNewInstance,
  }) {
    final instance = factory();
    onNewInstance?.call(instance);
    return instance;
  }

  @override
  void reset() {}
}

class _SingletonScope implements Scope {
  final Map<Factory, Object> _instances = {};

  @override
  dynamic provideUsing(
    Factory factory, {
    OnNewInstance? onNewInstance,
  }) {
    if (_instances.containsKey(factory)) {
      return _instances[factory];
    }
    final instance = factory();
    _instances[factory] = instance;
    onNewInstance?.call(instance);
    return instance;
  }

  @override
  void reset() {}
}

class _CachedScope implements Scope {
  final Map<Factory, Object> _instances = {};

  @override
  dynamic provideUsing(
    Factory factory, {
    OnNewInstance? onNewInstance,
  }) {
    if (_instances.containsKey(factory)) {
      return _instances[factory];
    }
    final instance = factory();
    _instances[factory] = instance;
    onNewInstance?.call(instance);
    return instance;
  }

  @override
  void reset() {
    _instances.clear();
  }
}
