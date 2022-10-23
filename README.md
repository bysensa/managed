Small dependency injection library.

Pure, dependency free library for dependency injection without code generation and with small as possible boilerplate.

## Features
- Multitype dependency registration.
- Scope based dependency registration.
- Simple injection API

## Dependency registration
This library uses Module primitive for dependency registration code. When 
you want to register dependency for injection you should do next things.

1. Define module where dependency registration code will be declared.
```dart
class AppModule extends Module {
  AppModule() : super({});
}
```
 You can define more than one module. The amount of modules depends on your app 
 architecture.
 
2. Declare one or more dependency registration instances assigned to `static 
   final` variables. The registration of dependency performed by `Manage` class.

```dart
class AppModule extends Module {
  AppModule() : super({});
  
  static final service = Manage(Service.new);
}
```
The full code of new `Manage` instance look like this:
```dart
class AppModule extends Module {
  AppModule() : super({});

  static final service = Manage<RegistrationType>(
      ServiceFactory, 
      scope: Scope.unique, 
      dependsOn: [],
  );
}
```

In example above you can see some optional parameters. Parameter `scope` used 
to provide specific scope in which instance of dependency will be managed. 
Parameter `dependsOn` used to initialize registration of other dependencies 
necessary for this dependency.

You should keep in mind that value of static variables initialized on first 
use. This means that until you access the variable its value will not be 
created. Thats why we should use other static variables in `dependsOn` 
parameter.

The factory you provide at construction of `Manage` instance can be class 
constructor

```dart
Manage(Service.new);
```

or you can provide closure

```dart
Manage(() => Service());
```

In simple cases the generic type for Manage instance will be inferred 
automatically. But in some cases you should define generic parameter 
explicitly.
```dart
Manage<Service>(() => Service());
```

3. Use some static variables in super constructor
```dart
class AppModule extends Module {
  AppModule() : super({service});
  
  static final service = Manage(Service.new, dependsOn: [client]);
  static final client = Manage(HttpClient.new);
  
}
```
This step is necessary because some static variables may not be initialized.
This is necessary only for those variables that have not been used anywhere else.
In real code, we usually encounter a situation where some dependencies 
depend on others. In our case, accessing variables in the constructor that 
no one has referred to yet will lead to initialization of the values of 
these variables and the entire graph of variables on which it depends.

In example above when we use `service` variable in constructor its value 
will be created and also will be created value for `client` variable.

### Scopes
Scope is a mechanism which help control injection behaviour. This library 
provide three different implementation of `Scope`
- `unique` - create new instance every time
- `singleton` - create new instance only once and instance will never be dropped
- `cached` - create new instance and store it until `reset`. When `reset` 
  method called than previously created instances will be dropped.

Every instance provided from scope created by factory provided at 
construction of `Manage` instance. If you use `cached` or `singleton` scope 
than instances provided from scope will be stored in pair with its factory. 
This allows us to make registration with different type and same factory and 
at the time of access same instance will be shared with different types

4. Mix `Managed` mixin where you wnt to use dependency
```dart
class Service with Managed {
  
}
```

The `Managed` mixin redefine `noSuchMethod` to implement injection behaviour
(See mixin implementation for more details). 

5. Define provider method to inject dependency
```dart
class Service with Managed {
  T _httpClient<T extends HttpClient>();
}
```

In example below we define method with generic parameter T which should 
extend HttpClient and without method body. Such declaration at runtime will 
 delegate all invocation to `noSuchMethod` where we have access to 
invocation details via `Invocation` class. The invocation class contains 
information about concrete values of generic parameters at the moment of 
call. In our example value of generic parameter will be `HttpClient` because we 
bound generic parameter by concrete type it must implement. And because we 
not specify generic parameter at the moment of call the value of parameter 
become equal to bounded type. And because we have concrete dependency type 
from generic parameter value we can find `Manage` instance with equal type 
ant then get instance of type using concrete type factory and provided scope.

To provide dependency instance without `Managed` mixin and provider method 
you can use module static variable directly.

```dart
final service = AppModule.service();
```

For more information about usage and implementation see source code and test.

I will be back in future with more examples.

Thank you.