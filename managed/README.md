# managed

A Dart dependency injection library with callable registrations, three scopes
and optional code generation. Global modules are ordinary Dart classes with
static fields. Each `Manage` is lazy. Its `dependsOn` list supplies constructor
inputs and determines which changes invalidate its instances.

## Dependencies tied to a login

Keep the session in a singleton. Its class decides which updates start a new
lifetime for consumers. Here a profile refresh keeps the graph open and a
change of account ID invalidates it.

```dart
import 'package:managed/managed.dart';

class UserSession with DependencyLifecycle {
  User? _user;
  User get user => _user ?? (throw StateError('Log in first'));

  Future<void> update(User? next) {
    final previous = _user;
    _user = next;
    if (previous?.id == next?.id) return Future.value();
    return dependencyChanged();
  }
}

abstract final class AuthModule {
  static final session = Manage(UserSession.new, scope: ScopeType.singleton);
  static final user = Manage(
    () => Manage.resolve<UserSession>().user,
    dependsOn: [session],
  );
}

abstract final class AccountsModule {
  static final repository = Manage(
    () => AccountRepository(Manage.resolve<User>()),
    dependsOn: [AuthModule.user],
    scope: ScopeType.cached,
  );
}
```

```dart
final session = AuthModule.session();
await session.update(alice);
final repo = AccountsModule.repository();
await session.update(aliceWithUpdatedName);
assert(identical(AccountsModule.repository(), repo));
assert(identical(AuthModule.user(), aliceWithUpdatedName));
await session.update(null); // Logout waits for the old graph to finish cleanup.
await session.update(bob);
final next = AccountsModule.repository();
```

The session publishes its new state before calling `dependencyChanged()`.
Affected cache entries are evicted immediately. Consumers are recreated on
their next successful lookup. A service that captured a profile in its
constructor keeps that snapshot until it is recreated.

## Initialization and disposal

Mix `DependencyLifecycle` into a class that owns resources. Each instance
stores a weak reference to its first `Manage` registration in a field, so
classes using the mixin have non-const constructors. `Manage` calls `init()`
synchronously on creation. A cache hit reuses the initialized object and its owner.
`dispose()` can be synchronous or return a `Future<void>`.

```dart
class AccountRepository with DependencyLifecycle {
  AccountRepository(this.user);
  final User user;
  late final Connection connection;

  @override
  void init() => connection = Connection.open(user.id);

  @override
  Future<void> dispose() => connection.close();
}
```

Await `dependencyChanged()` or `Scope.cached.reset()` to wait for disposal.
Consumers finish their cleanup before their inputs, so an editor can save a
draft through a still-open repository. Overlapping invalidations wait for
the same cleanup. A failed disposer propagates its error after the remaining
resources have been released. A factory's deferred `Manage.resolve<T>()`
throws if its input generation has expired.

For third-party objects, registrations also accept `onNewInstance` and
`onDispose`. If both forms are used, the object's hook runs first.
`mock()` and `resetMock()` invalidate consumers of the override. The test
retains ownership of the object it supplies as a mock.

## Scopes and registrations

- `unique` creates a fresh instance per call. Disposable inputs created for
  a managed graph are released with it. The caller disposes a standalone
  unique resource without a managed lifetime.
- `cached` reuses an instance until an input changes or `Scope.cached.reset()`
  is called. A reset also evicts transitive consumers in other scopes.
- `singleton` reuses an instance while its declared inputs remain valid.
  A shared session can signal repeatedly over its lifetime.

Within a scope, registrations with the same factory, declared inputs and
resolution key share a cache entry. A typed view from `.as<T>()` observes the
original registration. Two consumers that receive distinct unique instances
observe the changes of their respective inputs.

## Several inputs of one type

Give each registration a `resolutionKey` and pass it to `resolve`. A key can
be any object: an enum value, a module type or a string. The top-level
`resolve` is a shorthand for `Manage.resolve`.

```dart
enum Texts { help, notes }

abstract final class TextModule {
  static final help = Manage(TextCache.new,
      scope: ScopeType.cached, resolutionKey: Texts.help);
  static final notes = Manage(TextCache.new,
      scope: ScopeType.cached,
      dependsOn: [AuthModule.user],
      resolutionKey: Texts.notes);
  static final search = Manage(
    () => Search(resolve(Texts.help), resolve(Texts.notes)),
    dependsOn: [help, notes],
  );
}
```

A lookup without a key still finds an input by its type.

The offline notebook includes login, profile refresh, account switching, cache
resets, generated providers and tests with replacement storage.
[Notebook walkthrough](example/README.md)
