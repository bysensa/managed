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
