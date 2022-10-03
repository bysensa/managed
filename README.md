Small experimental dependency injection library.

The main purpose of this library is to test the hypothesis that it is possible to implement a dependency injection mechanism sufficient for comfortable use, not requiring explicit type conversion and sufficient to close the basic needs for dependency injection.

## Features
- simple way to define dependency providers
- small and clean implementation
- simple way to register dependency
- multi-type dependency registration

## Getting started
First: Register your dependencies
```dart
void register() {
  SpecificType().availableAs<SomeImplementedType>();
  AnotherType()
      .availableAs<AnotherImplementedType>()
      .availableAs<SomeAnotherImplementedType>();
}
```
Second: Define provider methods in class where you need registered dependencies.
```dart
class ConcreteType with Managed {
  T dependency<T extends SomeImplementedType>();
  T anotherDependency<T extends AnotherImplementedType>();
}

class ConcreteType with Managed {
  T dependency<T extends SomeAnotherImplementedType>();
}
```

Happy coding for you!!

## Usage


### Retrieve instance
Mix Managed mixin to class where DI needs and define method without body and 
with bounded type parameter.
```dart
class ConcreteType with Managed {
  T dependencyInstance<T extends Dependency>();
}
```
You can define multiple public or private methods as described below in any 
class. If class already overrides `noSuchMethod` when you should define 
separate class which can be embedded in target class only for DI purpose. 
For example:
```dart
class ConcreteType {
  final _dependencies = _Dependencies();
  
  dynamic noSuchMethod(Invocation invocation) {
    /// some other code here
  }
}

class _Dependencies with Managed {
  T dependencyInstance<T extends Dependency>();
}

```

### Register specific type

```dart
SpecificType().availableAs<SomeType>();
```
or if you need register instance by multiple types you can call 
`availableAs` in chain.
```dart
SpecificType()
    .availableAs<SomeType>()
    .availableAs<AnotherType>()
    .availableAs<SomeAnotherType>();
```
Keep in mind that `availableAs` function only available for types which implements `Manageable` mixin

### Check specific type registered or not

```dart
ManagementContainer.isRegistered<SpecificType>();
```
or
```dart
ManagementContainer.isNotRegistered<SpecificType>();
```

### Remove all dependencies from container

```dart
ManagementContainer.reset();
```

### Remove registration for specific type

```dart
ManagementContainer.remove<SpecificType>();
```
