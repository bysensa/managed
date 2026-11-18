# Managed workspace

Use Dart 3.6 or a later Dart 3 release. This repository includes
[managed](managed/), the dependency injection library, and
[managed_gen](managed_gen/), its code generator.

From the workspace root, resolve the dependencies for both packages with
`dart pub get`. Pub uses the local `managed` package when resolving
`managed_gen`.

Run the test suites from their respective package directories.

```sh
(cd managed && dart test)
(cd managed_gen && dart test)
```
