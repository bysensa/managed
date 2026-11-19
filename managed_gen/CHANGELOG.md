## Unreleased

- Generated registrations participate in instance lifecycle notifications and
  call the hooks of classes that mix in `DependencyLifecycle` through `Manage`.
- Preserve constructor defaults, nullability, generic bounds and nested types.
  Bind repeated unique inputs independently and reuse providers across packages.
- Select public constructors and binding names through `@ManagedType`.
  Generated providers support per-type registrations and lifecycle callbacks.
- Detect cycles, inaccessible signatures and name conflicts during generation.
  Track changes to part files and dependency packages in incremental builds.
- Generated `register()` accepts a `resolutionKey`, passed to `Manage`.
  Regenerate `module.dart` to use it.
- Generated code imports `package:managed/codegen.dart` and passes `Params`
  through `callWithParams`. Application code keeps importing
  `package:managed/managed.dart`, which no longer exposes `Params`.

## 0.0.2-dev.1

- Generate calls through the lifecycle-aware `Manage.call` in managed 2.
  Regenerate providers to bind constructor parameters and create unique
  dependencies only when a new instance is needed.

## 0.0.1

* TODO: Describe initial release.
