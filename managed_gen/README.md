# managed_gen

`managed_gen` builds `lib/module.dart` from classes annotated with
`@ManagedType`. Each binding has a callable registration and a `Params`
class for its constructor inputs. The application can keep registrations in
global modules and use the same scopes and lifecycle callbacks as `Manage`.

## Generate a provider

Add `managed` as a dependency and `managed_gen` and `build_runner` as dev
dependencies. Put the annotated classes under `lib/`.

```dart
import 'package:managed/annotations.dart';

@ManagedType(scope: ScopeType.cached)
class Style {
  Style({this.prefix = '##'});
  final String prefix;
}

@ManagedType(scope: ScopeType.unique)
class Heading {
  Heading(this.style, this.title);
  final Style style;
  final String title;
}
```

Run the builder from the package that owns the annotations.

```sh
dart run build_runner build
```

Import the generated `module.dart` to use the registrations.

```dart
StyleProvider.params = StyleParams(prefix: '#');
final first = HeadingProvider.provider(HeadingParams(title: 'Monday'));
final next = HeadingProvider.provider(HeadingParams(title: 'Tuesday'));
assert(identical(first.style, next.style));
```

The provider uses explicit call parameters first, then its configured defaults.
A cache hit or mock returns immediately. A cache miss that needs a required
argument throws a `StateError` naming the missing `Params`. A constructor with
sufficient defaults can be called as `StyleProvider.provider()`.

Cached and singleton registrations of one class share an instance unless their
`dependsOn` or `resolutionKey` differ. Params configure that instance when it
is created. Give each differently configured registration its own key.

```dart
final headings = StyleProvider.register(
    params: StyleParams(prefix: '#'), resolutionKey: #headings);
final quotes = StyleProvider.register(
    params: StyleParams(prefix: '>'), resolutionKey: #quotes);
```

## Bind a session to a generated graph

An annotated session can mix in `DependencyLifecycle`. Its `update` method
stores the latest account and calls `dependencyChanged()` when the account ID
changes or the user logs out. Configure the generated registrations once in a
global module.

```dart
final session = AccountSessionProvider.provider;
final user = Manage(
  () => Manage.resolve<AccountSession>().user,
  dependsOn: [session],
);
final cache = AccountCacheProvider.register(dependsOn: [user]);
final editor = EditorProvider.register(dependsOn: [cache]);
```

Here `AccountCache(Account user)` is cached and `Editor(AccountCache cache)`
is a singleton. An explicit input replaces the inferred registration of the
same type. Other entries add lifecycle dependencies. A refresh with the same
ID keeps the editor. Both `await session().update(null)` and
`await Scope.cached.reset()` release the editor before its cache. Classes
can implement `init()` and `dispose()` directly through the mixin.
Registrations also accept `params`, `onNewInstance`, `onDispose` and a
`resolutionKey`. A hand-written factory selects a keyed registration with
`resolve<T>(key)` when several inputs share a type.
[Executable session example](test/fixtures/client/test/bindings_test.dart.fixture)

## Constructor inputs

- Positional and named Dart inputs become named fields in `FooParams`.
  Nullability and defaults are preserved, including collection constants,
  records and function tear-offs private to the declaring library.
- A `unique` input can receive nested `Params`. Two arguments of the same
  type can receive different values. Omitting nested parameters for a
  non-nullable input delegates to its provider. Passing `null` for a nullable
  unique input passes `null` to the constructor. A cached or singleton input
  normally comes from its own registration, including a nullable declaration.
- When an optional input has a non-scalar default, omitting it lets Dart apply
  the original constructor default. For a nullable input with such a default,
  the generated constructor accepts `Object?` to distinguish omission from an
  explicit `null`. It checks the declared type when constructing `Params`. When supplying
  a later optional positional argument, also supply any preceding argument
  whose default is private or otherwise cannot be emitted as a literal.
- For a generic class, use `BoxProvider.of<int>()` and `BoxParams<int>(...)`.
  Each specialization has its own registration. For a shared scope, set
  `BoxProvider.of<int>().params` to configure that specialization.
- The generator prefers the unnamed constructor, then the sole public named
  constructor. Use `@ManagedType(scope: ScopeType.cached, constructor: 'open')`
  to select a specific constructor. Abstract classes need a callable public
  factory. Use `name: 'LocalItem'` when classes in different libraries would
  generate the same binding names.
- Classes in a `part` belong to their enclosing library. A `generate_for`
  filter can select the enclosing library and its local annotated constructor
  dependencies are included transitively. For a dependency owned by another
  package, generate and ship that package's `lib/module.dart`. Both packages
  then use its original registration.

Generation reports dependency cycles, inaccessible types or constructors,
ambiguous names and missing bindings in dependency packages. The annotated
class and the types its generated API refers to must be accessible from
`module.dart`.

The generator uses `analyzer` 6.x. The build log reports the language versions
of the analyzer and the installed SDK when they differ. Newer SDK syntax also
needs support from the analyzer used by the builder.

## Run the example and tests

The notebook generates its Markdown providers and uses a session singleton for
its editor. [Notebook walkthrough](../managed/example/README.md)

Run `dart test` in `managed_gen`. The integration suite builds two temporary
consumer packages under the package's `.dart_tool`, analyzes the generated
module, runs its behavior tests, and checks incremental and clean rebuilds.
