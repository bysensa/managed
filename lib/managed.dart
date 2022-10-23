library managed;

import 'package:meta/meta.dart';

typedef Factory<T> = T Function();
typedef ManagedBy = Set<Manage>;

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
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName;
    final types = invocation.typeArguments;
    final isProvider = invocation.isMethod && types.length == 1;

    if (!isProvider) {
      throw StateError(
        'Unexpected dependency provider ($memberName).'
        'Provider function must be defined as: \n'
        'T {providerName}<T extends {dependencyType}>([_ = {providerModule}.new])',
      );
    }

    final type = types.first;
    final maybeTargetType = Manage.manageInstance(type)?._bind(this);
    if (maybeTargetType == null) {
      throw StateError('Type $type is not registered');
    }
    return maybeTargetType;
  }
}

/// This class should be implemented by other modules.
abstract class Module {
  /// Base constructor for modules. Each module which extends Module class must
  /// invoke super constructor. Parameter [instances] is necessary in case when
  /// module contains variables not used in [Manage.dependsOn] parameter. For such variables
  /// we should invoke them some where else and [instances] parameter is such place.
  ///
  /// For example:
  /// ```dart
  ///
  /// class AppModule extends Module {
  ///
  ///   AppModule() : super({dependency2})
  ///
  ///   static final dependency1 = Manage(Dependency1.new);
  ///   static final dependency2 = Manage(Dependency1.new, dependsOn: [dependency1]);
  /// }
  /// ```
  ///
  /// In example above we have two dependencies provided by Manage instances.
  /// Because Manage instances assign to static variables its initialization performed
  /// on first access. This mean that dependency1 will be initialized when somebody
  /// use dependency2. That's why we should provide dependency2 as argument at construction of
  /// AppModule. So, at creation of AppModule we access dependency2 instance which will lead
  /// to the creation of dependency1 instance
  const Module(Set<Manage> instances);
}

/// Class used to register specific Type and instance factory for it. This class
/// must be used together with static variable. Instance of this class should be created
/// only once for concrete type [T].
class Manage<T extends Object> {
  /// Hold binding between instance of Manage class and its generic type.
  static final _typeBindings = Expando<Manage>();

  /// Provides instance of [Manage] for [Type] parameter [type].
  ///
  /// Method can return null if [_typeBindings] does not contain [Manage] instance for
  /// provided [type]
  static Manage? manageInstance(Type type) => _typeBindings[type];

  /// Drop [Manage] instance registered for [Type] provided in parameter [type]
  @visibleForTesting
  static void resetTypeInstance(Type type) => _typeBindings[type] = null;

  /// Hold pair of class reference and and instances created using [_factory]
  ///
  /// Such binding is necessary because instances of type [T] provided from methods
  /// and we cant store them by default. This mean that without correct storage mechanism
  /// every time user call method which provide instance of type [T] he will receive
  /// new instance and such behaviour is incorrect. Expando type allow us store
  /// binding between some instance and instance of type [T] while some instance
  /// live in memory
  final _instanceBindings = Expando<T>();

  ///
  final Scope _scope;

  /// Factory which provide instances of type [T]
  final Factory<T> _factory;

  /// This variable used in test when we want to mock type [T] with out changing
  /// behaviour of dependency injection
  T? _mock;

  Manage(
    this._factory, {
    Scope? scope,
    List? dependsOn,
  }) : _scope = scope ?? Scope.unique {
    _typeBindings[T] = this;
  }

  /// Returns instance of type [T]
  ///
  /// If mock is provided using [mock] method when instance from [_mock] variable
  /// will be returned else we receive instance from [_scope].
  T call() {
    return _mock ?? _scope.provideUsing(_factory);
  }

  /// Bind provided instance via [consumer] with instance of type [T] and when
  /// return instance of type [T]
  T _bind(Object consumer) {
    var instance = _instanceBindings[consumer];
    if (instance == null) {
      instance = call();
      _instanceBindings[consumer] = instance;
    }
    return instance;
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
  dynamic provideUsing(Factory factory);

  /// Drop previously created instances
  ///
  /// For [unique] and [singleton] implementation call of this method has no effect.
  /// For [cached] implementation its trigger drop of previously created instances.
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
