library managed;

/// Global dependency container which store dependency in map by type
///
/// Single dependency can be stored by multiple types.
var _container = <Type, Manageable>{};

/// Extension used to interact with dependency container
extension ManagementContainer on Expando {
  /// Remove instance from container by registration type and return this instance
  ///
  /// If instance is not registered previously then null will be returned
  static T? delete<T>() => _container.remove(T) as T?;

  /// Delete all instances from container
  static void reset() => _container.clear();

  /// Check instance is registered in container
  static bool isRegistered<T>() => _container[T] != null;

  /// Check instance is not registered in container
  static bool isNotRegistered<T>() => !isRegistered<T>();

  /// Put instance in container by type [S]
  ///
  /// If instance is not implements type [S] then [StateError] will be thrown
  static void _put<S>(Manageable instance) {
    if (instance is S) {
      _container[S] = instance;
    } else {
      throw StateError(
        'Type ${instance.runtimeType} does not implement Type $S',
      );
    }
  }
}

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
    final isManageableProvider = invocation.isMethod && types.length == 1;
    if (!isManageableProvider) {
      throw StateError('Unexpected dependency provider ($memberName)');
    }
    final type = types.first;
    final maybeTargetType = _container[type];
    if (maybeTargetType == null) {
      throw StateError('Type $type is not registered');
    }
    return maybeTargetType;
  }
}

/// Marker mixin.
///
/// All dependencies which should be registered must implement this mixin
mixin Manageable {}

/// Extension for [Manageable] mixin
extension ManageableRegistrationExt<T extends Manageable> on T {
  /// Perform registration instance of type [T] by specified generic type [S]
  ///
  /// The [StateError] can be thrown if type [T] is not implement type [S]. Instance [T]
  /// will be returned after registration
  T availableAs<S>() {
    ManagementContainer._put<S>(this);
    return this;
  }
}
