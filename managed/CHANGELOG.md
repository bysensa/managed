## Unreleased

- Replace `Manage.source` with `DependencyLifecycle`. Session objects can now
  signal identity changes with `dependencyChanged()` and implement synchronous
  `init()` and synchronous or asynchronous `dispose()` themselves.
- Allow `@ManagedType` to select a constructor and override the generated
  binding name.
- `Manage.resolve` requires a non-nullable type argument. A lookup for a
  nullable parameter now infers the non-nullable type and receives the
  declared input instead of `null`. An explicit `Manage.resolve<T?>()` no
  longer compiles, and a lookup without a type context throws a `StateError`
  instead of returning `null`.
- During a cleanup, a disposer that calls a registration closer to the root
  receives the instance that is still being released instead of a new one
  built for the next state. Calling a consumer that the same cleanup has
  already released throws a `StateError`. Disposers no longer run in the
  resolution of the code that triggered the invalidation, so a logout from a
  stream callback inside a factory no longer rejects their lookups.
- Add an optional `resolutionKey` to `Manage`. `Manage.resolve<T>(key)`
  selects the input registered with that key, so a factory can tell inputs of
  one type apart. Any object can be a key. Registrations with different keys
  do not share a cached instance. A lookup without a key is unchanged.
- Add a top-level `resolve<T>([resolutionKey])` that calls `Manage.resolve`.
- `Params` and `ZoneValues` are only available to generated code through
  `package:managed/codegen.dart`. `Manage.call()` takes no arguments; generated
  providers keep their typed `call([FooParams? params])`. Pass call arguments
  to a hand-written registration through its factory closure instead.
  Regenerate `module.dart` with this version of `managed_gen`.
- Remove `Manage.callForGenerated()` and `nonNullableTypeOf`. `provide()` is
  no longer part of the API.
- `as<S>()` checks the type of the registration instead of its factory. A
  narrowing view such as `Manage<NoteStorage>(MemoryStorage.new)
  .as<MemoryStorage>()` now throws the documented `StateError` instead of a
  `TypeError`.

## 2.0.0-dev.1

- Add `Manage.source` with configurable identity and transitive invalidation
  through `dependsOn`. Registrations accept synchronous or asynchronous
  `onDispose` callbacks.
- `Scope.reset()`, `mock()` and `resetMock()` return `Future<void>`. Await them
  to wait for disposal. Custom `Scope` implementations now provide a generic
  `provideUsing<T>` with an optional `OnDispose<T>` callback.
- Cached registrations share an instance when their factory and declared
  inputs match.

## 0.0.1

* TODO: Describe initial release.
