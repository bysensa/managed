library managed;

import 'package:flutter/foundation.dart';

typedef Factory<T> = T Function();
typedef DependsOn = Set<Manage>;

/// Mixin used to provide dependency injection in target class
///
/// Dependency injection implemented by overriding [Object.noSuchMethod].
/// Parameter [Invocation] allow access to type parameters of target method.
/// This behaviour allows us get concrete Type at runtime and retrieve instance by this type
///
/// Example
/// ```dart
/// class Dependency with Manageable {}
///
/// class ManagedObject with Managed {
///   T dependencyInstance<T extends Dependency>();
/// }
/// ```
///
/// In the example below we define two classes. First class is `Dependency`. Instance
/// of this class will be retrieved from dependency container. The second class is
/// `ManagedObject`. Instance of this class becomes a consumer of `Dependency` instance.
/// To get instance of `Dependency` we specify method `dependencyInstance` with out body and
/// with type parameter <T extends Dependency>. By specifying bound of type parameter
/// we declare that resulting type should implement bounded type. When this method will be invoked
/// its invocation will be delegated to noSuchMethod because we did not declare implementation.
/// The invocation parameter will be contains list of type parameters. For example below list of type
/// parameters will be equal to [[Dependency]]. Not all methods will be treated as
/// dependency provider method. We try to retrieve dependency only if invocation is method
/// and have only one type parameter. For other cases StateError exception will be thrown.
/// If Dependency is not registered or type parameter is wrong then StateError will be thrown
mixin Managed {
  DependsOn get dependsOn => {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName;
    final types = invocation.typeArguments;
    final isProvider = invocation.isMethod && types.length == 1;
    if (!isProvider) {
      throw StateError('Unexpected dependency provider ($memberName)');
    }
    final type = types.first;
    final maybeTargetType = Manage.manageInstance(type)?._bind(this);
    if (maybeTargetType == null) {
      throw StateError('Type $type is not registered');
    }
    return maybeTargetType;
  }
}

/// Extension for Managed instances
extension ManagedExt<T extends Managed> on T {
  /// Activate dependencies registration
  ///
  /// Example:
  /// ```dart
  /// class SomeModule {
  ///   static final dependency = Manage(Dependency.new);
  /// }
  ///
  /// class SomeObject with Managed {
  ///   T dependency<T extends Dependency>();
  /// }
  ///
  /// SomeObject().dependsOn({SomeModule.dependency});
  /// ```
  T dependsOn(DependsOn manageBy) {
    return this;
  }
}

class Manage<T extends Object> {
  static final _manageInstances = Expando<Manage>();
  static Manage? manageInstance(type) => _manageInstances[type];

  @visibleForTesting
  static void resetTypeInstance(Type type) => _manageInstances[type] = null;

  final _bindings = Expando<T>();
  final Scope _scope;
  final Factory<T> _factory;
  T? _mock;

  Manage(
    this._factory, {
    Scope? scope,
    List? dependsOn,
  }) : _scope = scope ?? Scope.unique {
    _manageInstances[T] = this;
  }

  T call() {
    return _mock ?? _scope.provideUsing(_factory);
  }

  T _bind(Object consumer) {
    var instance = _bindings[consumer];
    if (instance == null) {
      instance = call();
      _bindings[consumer] = instance;
    }
    return instance;
  }

  @visibleForTesting
  void mock(T instance) {
    _mock = instance;
  }

  @visibleForTesting
  void resetMock() {
    _mock = null;
  }
}

abstract class Scope {
  static final Scope unique = _UniqueScope();
  static final Scope singleton = _SingletonScope();
  static final Scope cached = _CachedScope();

  dynamic provideUsing(Factory factory);
  void reset();
}

class _UniqueScope implements Scope {
  @override
  dynamic provideUsing(Factory factory) {
    return factory();
  }

  @override
  void reset() {}
}

class _SingletonScope implements Scope {
  final Map<Factory, Object> _instances = {};

  @override
  dynamic provideUsing(Factory factory) {
    if (_instances.containsKey(factory)) {
      return _instances[factory];
    }
    final instance = factory();
    _instances[factory] = instance;
    return instance;
  }

  @override
  void reset() {}
}

class _CachedScope implements Scope {
  final Map<Factory, Object> _instances = {};

  @override
  dynamic provideUsing(Factory factory) {
    if (_instances.containsKey(factory)) {
      return _instances[factory];
    }
    final instance = factory();
    _instances[factory] = instance;
    return instance;
  }

  @override
  void reset() {
    _instances.clear();
  }
}
