import 'dart:async';

import 'package:managed/managed.dart';
import 'package:test/test.dart';

class _User {
  _User(this.id, this.name);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is _User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class _Transport {}

abstract interface class _Accounts {
  _User get user;
}

class _Repository implements _Accounts {
  _Repository(this.user, this.transport);

  @override
  final _User user;
  final _Transport transport;
}

class _Controller {
  _Controller(this.accounts);

  final _Accounts accounts;
}

class _SessionGraph {
  final disposed = <Object>[];
  final user = Manage.source<_User>(sameIdentity: (a, b) => a.id == b.id);
  final transport = Manage(_Transport.new, scope: ScopeType.singleton);
  late final repository = Manage(
    () => _Repository(Manage.resolve(), Manage.resolve()),
    dependsOn: [user, transport],
    scope: ScopeType.cached,
    onDispose: disposed.add,
  );
  late final controller = Manage(
    () => _Controller(Manage.resolve()),
    dependsOn: [repository.as<_Accounts>()],
    scope: ScopeType.singleton,
    onDispose: disposed.add,
  );
}

void main() {
  tearDown(Scope.cached.reset);

  test('logout releases the user graph and the next login builds a new one',
      () async {
    final graph = _SessionGraph();
    final transport = graph.transport();
    expect(() => graph.controller(), throwsStateError);

    final alice = _User(1, 'Alice');
    await graph.user.set(alice);
    final controller = graph.controller();
    final repository = graph.repository();
    expect(controller.accounts, same(repository));
    expect(repository.user, same(alice));

    final refreshed = _User(1, 'Alice Smith');
    await graph.user.set(refreshed);
    expect(graph.user(), same(refreshed));
    expect(graph.controller(), same(controller));
    expect(graph.repository(), same(repository));
    expect(graph.disposed, isEmpty);

    await graph.user.clear();
    expect(graph.disposed, [controller, repository]);
    expect(() => graph.user(), throwsStateError);
    expect(() => graph.repository(), throwsStateError);
    expect(() => graph.controller(), throwsStateError);
    await graph.user.clear();
    expect(graph.disposed, [controller, repository]);

    final bob = _User(2, 'Bob');
    await graph.user.set(bob);
    final next = graph.controller();
    expect(next, isNot(same(controller)));
    expect(next.accounts, same(graph.repository()));
    expect(next.accounts, isNot(same(repository)));
    expect(next.accounts.user, same(bob));
    expect(graph.repository().transport, same(transport));
  });

  test('switching users directly also invalidates their dependents', () async {
    final graph = _SessionGraph();
    await graph.user.set(_User(1, 'Alice'));
    final previous = graph.controller();
    final bob = _User(2, 'Bob');
    await graph.user.set(bob);
    expect(graph.disposed, [previous, previous.accounts]);
    expect(graph.controller().accounts.user, same(bob));
  });

  test('logging back in with the same user starts a new lifetime', () async {
    final graph = _SessionGraph();
    final alice = _User(1, 'Alice');
    await graph.user.set(alice);
    final previous = graph.controller();
    await graph.user.clear();
    await graph.user.set(alice);
    final next = graph.controller();
    expect(next, isNot(same(previous)));
    expect(next.accounts, isNot(same(previous.accounts)));
    expect(next.accounts.user, same(alice));
  });

  test('an empty source prevents allocation of sibling dependencies', () {
    final source = Manage.source<_User>();
    var builds = 0;
    final sibling = Manage(() => ++builds);
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [sibling, source]);
    expect(() => consumer(), throwsStateError);
    expect(builds, 0);
  });

  test('a source compares object identity by default', () async {
    final user = Manage.source<_User>();
    final disposed = <Object>[];
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [user], onDispose: disposed.add);
    final first = _User(1, 'Alice');
    await user.set(first);
    final original = consumer();
    await user.set(first);
    expect(consumer(), same(original));
    final equal = _User(1, 'Alice');
    expect(equal, equals(first));
    await user.set(equal);
    expect(consumer(), isNot(same(original)));
    expect(disposed, [original]);
  });

  test('the source disposes its latest snapshot after its consumers', () async {
    final disposed = <Object>[];
    final user = Manage.source<_User>(
        sameIdentity: (a, b) => a.id == b.id, onDispose: disposed.add);
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [user], onDispose: disposed.add);
    final alice = _User(1, 'Alice');
    final updated = _User(1, 'Alice Smith');
    await user.set(alice);
    final first = consumer();
    await user.set(updated);
    expect(disposed, isEmpty);
    await Scope.cached.reset();
    expect(disposed, [first]);
    final second = consumer();
    await user.clear();
    expect(disposed, hasLength(3));
    expect(disposed[1], same(second));
    expect(disposed[2], same(updated));
  });

  test('cached reset releases consumers across scopes and preserves the login',
      () async {
    final graph = _SessionGraph();
    final alice = _User(1, 'Alice');
    await graph.user.set(alice);
    final controller = graph.controller();
    final repository = graph.repository();

    await Scope.cached.reset();
    expect(graph.disposed, [controller, repository]);
    expect(graph.user(), same(alice));
    final next = graph.controller();
    expect(next, isNot(same(controller)));
    expect(next.accounts, isNot(same(repository)));
    expect(next.accounts.user, same(alice));
    expect(graph.repository().transport, same(repository.transport));
  });

  test('a shared factory only reuses instances with the same inputs', () async {
    final disposed = <Object>[];
    final user = Manage.source<_User>();
    final global = Manage(Object.new, scope: ScopeType.singleton);
    final personal = Manage(Object.new,
        scope: ScopeType.singleton, dependsOn: [user], onDispose: disposed.add);
    final alias = Manage(Object.new,
        scope: ScopeType.singleton, dependsOn: [user], onDispose: disposed.add);
    final appInstance = global();
    expect(() => personal(), throwsStateError);
    await user.set(_User(1, 'Alice'));
    final userInstance = personal();
    expect(alias(), same(userInstance));
    expect(userInstance, isNot(same(appInstance)));
    await user.clear();
    expect(disposed, [userInstance]);
    expect(() => alias(), throwsStateError);
    expect(global(), same(appInstance));
  });

  test('a cached graph owns its unique dependencies, including shared inputs',
      () async {
    final disposed = <Object>[];
    final leaf = Manage(() => _User(1, 'Alice'),
        scope: ScopeType.cached, onDispose: disposed.add);
    var builds = 0;
    final middle = Manage(
      () {
        builds++;
        return _Repository(Manage.resolve(), _Transport());
      },
      dependsOn: [leaf],
      onDispose: disposed.add,
    );
    final root = Manage(
      () => _Controller(Manage.resolve<_Repository>()),
      scope: ScopeType.singleton,
      dependsOn: [middle, leaf],
      onDispose: disposed.add,
    );
    final previous = root();
    final input = leaf();
    expect(root(), same(previous));
    expect(builds, 1);
    await Scope.cached.reset();
    expect(disposed, [previous, previous.accounts, input]);
    expect(root().accounts.user, isNot(same(input)));
    expect(builds, 2);
  });

  test('cached reset releases a unique child with no inputs of its own',
      () async {
    final disposed = <Object>[];
    final leaf = Manage(() => _User(1, 'Alice'), onDispose: disposed.add);
    final owner = Manage(
      () => _Repository(Manage.resolve(), _Transport()),
      scope: ScopeType.cached,
      dependsOn: [leaf],
      onDispose: disposed.add,
    );
    final unrelated = leaf();
    final previous = owner();
    await Scope.cached.reset();
    expect(disposed, [previous, previous.user]);
    expect(disposed, isNot(contains(same(unrelated))));
  });

  test('overlapping clears wait for disposal and preserve the new generation',
      () async {
    final user = Manage.source<_User>();
    final disposed = <String>[];
    final gate = Completer<void>();
    final repo = Manage(
      () => _Repository(Manage.resolve(), _Transport()),
      scope: ScopeType.cached,
      dependsOn: [user],
      onDispose: (value) => disposed.add('repository ${value.user.id}'),
    );
    final controller = Manage(
      () => _Controller(Manage.resolve<_Repository>()),
      scope: ScopeType.singleton,
      dependsOn: [repo],
      onDispose: (value) async {
        disposed.add('start ${value.accounts.user.id}');
        await gate.future;
        disposed.add('end ${value.accounts.user.id}');
      },
    );
    await user.set(_User(1, 'Alice'));
    final oldController = controller();
    final logout = user.clear();
    expect(() => controller(), throwsStateError);
    var resetFinished = false;
    final reset = Scope.cached.reset().then((_) => resetFinished = true);
    final login = user.set(_User(2, 'Bob'));
    final next = controller();
    await Future<void>.value();
    expect(resetFinished, isFalse);
    expect(next, isNot(same(oldController)));
    expect(disposed, ['start 1']);
    gate.complete();
    await Future.wait([logout, reset, login]);
    expect(disposed, ['start 1', 'end 1', 'repository 1']);
    expect(controller(), same(next));
  });

  test('a failing disposer still releases the remaining dependencies',
      () async {
    final graph = _SessionGraph();
    final error = StateError('close failed');
    final consumer = Manage(
      Object.new,
      scope: ScopeType.cached,
      dependsOn: [graph.controller],
      onDispose: (_) async => throw error,
    );
    await graph.user.set(_User(1, 'Alice'));
    final previous = consumer();
    final controller = graph.controller();
    await expectLater(graph.user.clear(), throwsA(same(error)));
    expect(graph.disposed, [controller, controller.accounts]);
    expect(() => consumer(), throwsStateError);

    await graph.user.set(_User(2, 'Bob'));
    expect(consumer(), isNot(same(previous)));
    await expectLater(graph.user.clear(), throwsA(same(error)));
  });

  test('a disposer can await a scope reset during logout', () async {
    final graph = _SessionGraph();
    final disposed = <Object>[];
    final other =
        Scope.cached.provideUsing(Object.new, onDispose: disposed.add);
    final consumer = Manage(Object.new,
        dependsOn: [graph.controller],
        scope: ScopeType.cached,
        onDispose: (_) => Scope.cached.reset());
    await graph.user.set(_User(1, 'Alice'));
    consumer();
    final controller = graph.controller();
    await graph.user.clear();
    expect(graph.disposed, [controller, controller.accounts]);
    expect(disposed, [other]);
  });

  test('a deferred lookup from the old login cannot resolve the new user',
      () async {
    final graph = _SessionGraph();
    final gate = Completer<void>();
    final lookup = Manage(
      () => gate.future.then((_) => Manage.resolve<_User>()),
      scope: ScopeType.cached,
      dependsOn: [graph.user],
    );
    await graph.user.set(_User(1, 'Alice'));
    final old = lookup();
    await graph.user.clear();
    final bob = _User(2, 'Bob');
    await graph.user.set(bob);
    final next = lookup();
    final rejected = expectLater(old, throwsStateError);
    gate.complete();
    await rejected;
    expect(await next, same(bob));
  });

  test('overriding a dependency invalidates consumers of its typed view',
      () async {
    final graph = _SessionGraph();
    await graph.user.set(_User(1, 'Alice'));
    final original = graph.controller();
    final mock = _Repository(_User(2, 'Test'), _Transport());
    await graph.repository.mock(mock);
    final overridden = graph.controller();
    expect(overridden.accounts, same(mock));
    expect(graph.disposed, [original]);
    await graph.repository.resetMock();
    expect(graph.controller().accounts, same(original.accounts));
    expect(graph.disposed, [original, overridden]);
  });

  test('a factory that logs out cannot publish a stale instance', () async {
    final graph = _SessionGraph();
    late Future<void> logout;
    final consumer = Manage(
      () {
        final old = Manage.resolve<_Controller>();
        logout = graph.user.clear();
        return old.accounts.user;
      },
      dependsOn: [graph.controller],
      scope: ScopeType.cached,
      onDispose: graph.disposed.add,
    );
    final alice = _User(1, 'Alice');
    await graph.user.set(alice);
    final controller = graph.controller();
    expect(() => consumer(), throwsStateError);
    await logout;
    expect(graph.disposed, [alice, controller, controller.accounts]);
    expect(() => consumer(), throwsStateError);
  });
}
