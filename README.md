# Managed workspace

Use Dart 3.6 or a later Dart 3 release. This repository includes
[managed](managed/), the dependency injection library, and
[managed_gen](managed_gen/), its code generator.

The [offline notebook example](managed/example/README.md) uses both packages.
From the workspace root, run the full login, editing and account-switching
scenario with

```sh
dart pub get
dart run managed/example/managed_example.dart
```

Run the test suites from their respective package directories.

```sh
(cd managed && dart test)
(cd managed_gen && dart test)
(cd managed/example && dart test)
```
