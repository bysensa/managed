Small dependency injection library.

A Dart library for dependency injection with optional code generation.

## Features

- Multitype dependency registration.
- Scope based dependency registration.
- Transitive invalidation and disposal through `dependsOn`.
- Simple injection API

## Getting started

Run the [offline notebook example](example/README.md) to follow instances
through login, profile updates, cache resets and logout. It includes typed
parameters, generated providers and tests with a replacement storage service.

### Dependencies tied to a login

Register the current user once. Global modules can use the same source in
`dependsOn`, including through another module's registration.

```dart
abstract final class AuthModule {
  static final user = Manage.source<User>(
    sameIdentity: (previous, next) => previous.id == next.id,
  );
}

abstract final class AccountsModule {
  static final repository = Manage(
    () => AccountRepository(Manage.resolve<User>().id),
    scope: ScopeType.cached,
    dependsOn: [AuthModule.user],
    onDispose: (repo) => repo.close(),
  );
}

abstract final class ProfileModule {
  static final controller = Manage(
    () => ProfileController(Manage.resolve<AccountRepository>()),
    scope: ScopeType.singleton,
    dependsOn: [AccountsModule.repository],
    onDispose: (controller) => controller.dispose(),
  );
}
```

```dart
await AuthModule.user.set(alice);
final controller = ProfileModule.controller();

await AuthModule.user.set(aliceWithUpdatedName);
assert(identical(AuthModule.user(), aliceWithUpdatedName));
assert(identical(ProfileModule.controller(), controller));

await AuthModule.user.clear(); // Disposes the controller, then the repository.
await AuthModule.user.set(bob);
final nextController = ProfileModule.controller(); // Builds Bob's graph.
```

An empty source and any registration that requires it throw `StateError` on
access. By default a source compares values with `identical`. A custom
`sameIdentity` can compare a user ID. A matching update replaces the value
returned by the source and preserves existing services. A service that stored
an earlier snapshot keeps that snapshot. Read the source again for fresh data.
Setting a different user directly also releases the previous user's graph.
If the supplied value owns resources, pass an `onDispose` callback to
`Manage.source`. It receives the latest snapshot of the outgoing identity
after its consumers have been disposed.

`await Scope.cached.reset()` clears cached instances and their transitive
consumers, including singletons, while the source keeps its current user.
Both reset and logout evict affected instances immediately. Their futures
complete after each `onDispose` has run once, with consumers disposed before
their dependencies. A callback may return `void` or `Future<void>`.

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
    scope: ScopeType.unique,
    dependsOn: [],
  );
}
```

In example above you can see some optional parameters. Parameter `scope` used
to provide specific scope in which instance of dependency will be managed.
The `dependsOn` registrations supply values to the factory and determine
when its instance must be released.

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
Manage(()=>Service());
```

In simple cases the generic type for Manage instance will be inferred
automatically. But in some cases you should define generic parameter
explicitly.

```dart
Manage<Service>(()=>Service());
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

- `unique` creates a fresh instance on each call. Disposable instances created
  for a managed graph are released with it. The caller owns a standalone
  unique instance with no source or cached lifetime.
- `singleton` reuses an instance while its declared dependencies remain valid.
  Calling `Scope.singleton.reset()` has no effect.
- `cached` reuses an instance until an input changes or `Scope.cached.reset()`
  is called.

Within a scope, registrations with the same factory and the same declared
inputs share a cached instance. The registration that constructs it supplies
its lifecycle callbacks. A typed view created with `.as<T>()` shares
the original registration's lifetime and disposal callback.

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
