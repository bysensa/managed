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

class _Session with DependencyLifecycle {
  _Session(this.sameUser, this.onEnded);
  final bool Function(_User, _User) sameUser;
  final void Function(_User)? onEnded;
  _User? _user;
  _User get user => _user ?? (throw StateError('Log in first.'));

  Future<void> login(_User next) => _update(next);
  Future<void> logout() => _update(null);
  Future<void> _update(_User? next) async {
    final old = _user;
    _user = next;
    if (old == null ? next == null : next != null && sameUser(old, next))
      return;
    await dependencyChanged();
    if (old != null) onEnded?.call(old);
  }
}

class _SessionGraph {
  _SessionGraph(
      {bool Function(_User, _User)? sameUser, void Function(_User)? onEnded}) {
    final state = _Session(sameUser ?? (a, b) => a.id == b.id, onEnded);
    session = Manage(() => state, scope: ScopeType.singleton);
  }

  final disposed = <Object>[];
  late final Manage<_Session> session;
  late final user =
      Manage(() => Manage.resolve<_Session>().user, dependsOn: [session]);
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
    await graph.session().login(alice);
    final controller = graph.controller();
    final repository = graph.repository();
    expect(controller.accounts, same(repository));
    expect(repository.user, same(alice));

    final refreshed = _User(1, 'Alice Smith');
    await graph.session().login(refreshed);
    expect(graph.user(), same(refreshed));
    expect(graph.controller(), same(controller));
    expect(graph.repository(), same(repository));
    expect(graph.disposed, isEmpty);

    await graph.session().logout();
    expect(graph.disposed, [controller, repository]);
    expect(() => graph.user(), throwsStateError);
    expect(() => graph.repository(), throwsStateError);
    expect(() => graph.controller(), throwsStateError);
    await graph.session().logout();
    expect(graph.disposed, [controller, repository]);

    final bob = _User(2, 'Bob');
    await graph.session().login(bob);
    final next = graph.controller();
    expect(next, isNot(same(controller)));
    expect(next.accounts, same(graph.repository()));
    expect(next.accounts, isNot(same(repository)));
    expect(next.accounts.user, same(bob));
    expect(graph.repository().transport, same(transport));
  });

  test('switching users directly also invalidates their dependents', () async {
    final graph = _SessionGraph();
    await graph.session().login(_User(1, 'Alice'));
    final previous = graph.controller();
    final bob = _User(2, 'Bob');
    await graph.session().login(bob);
    expect(graph.disposed, [previous, previous.accounts]);
    expect(graph.controller().accounts.user, same(bob));
  });

  test('logging back in with the same user starts a new lifetime', () async {
    final graph = _SessionGraph();
    final alice = _User(1, 'Alice');
    await graph.session().login(alice);
    final previous = graph.controller();
    await graph.session().logout();
    await graph.session().login(alice);
    final next = graph.controller();
    expect(next, isNot(same(previous)));
    expect(next.accounts, isNot(same(previous.accounts)));
    expect(next.accounts.user, same(alice));
  });

  test('a failed session lookup releases an already-created unique sibling',
      () async {
    final graph = _SessionGraph();
    var builds = 0;
    final released = <int>[];
    final sibling = Manage(() => ++builds, onDispose: released.add);
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [sibling, graph.user]);
    expect(consumer.call, throwsStateError);
    expect(released, [1]);
    await graph.session().login(_User(1, 'Alice'));
    consumer();
    await graph.session().logout();
    expect(released, [1, 2]);
  });

  test('a session can choose object identity instead of the account ID',
      () async {
    final graph = _SessionGraph(sameUser: identical);
    final user = graph.user;
    final disposed = <Object>[];
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [user], onDispose: disposed.add);
    final first = _User(1, 'Alice');
    await graph.session().login(first);
    final original = consumer();
    await graph.session().login(first);
    expect(consumer(), same(original));
    final equal = _User(1, 'Alice');
    expect(equal, equals(first));
    await graph.session().login(equal);
    expect(consumer(), isNot(same(original)));
    expect(disposed, [original]);
  });

  test('a session can release its latest snapshot after its consumers',
      () async {
    final disposed = <Object>[];
    final graph = _SessionGraph(onEnded: disposed.add);
    final user = graph.user;
    final consumer = Manage(Object.new,
        scope: ScopeType.cached, dependsOn: [user], onDispose: disposed.add);
    final alice = _User(1, 'Alice');
    final updated = _User(1, 'Alice Smith');
    await graph.session().login(alice);
    final first = consumer();
    await graph.session().login(updated);
    expect(disposed, isEmpty);
    await Scope.cached.reset();
    expect(disposed, [first]);
    final second = consumer();
    await graph.session().logout();
    expect(disposed, hasLength(3));
    expect(disposed[1], same(second));
    expect(disposed[2], same(updated));
  });

  test('cached reset releases consumers across scopes and preserves the login',
      () async {
    final graph = _SessionGraph();
    final alice = _User(1, 'Alice');
    await graph.session().login(alice);
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
    final graph = _SessionGraph();
    final user = graph.user;
    final global = Manage(Object.new, scope: ScopeType.singleton);
    final personal = Manage(Object.new,
        scope: ScopeType.singleton, dependsOn: [user], onDispose: disposed.add);
    final alias = Manage(Object.new,
        scope: ScopeType.singleton, dependsOn: [user], onDispose: disposed.add);
    final appInstance = global();
    expect(() => personal(), throwsStateError);
    await graph.session().login(_User(1, 'Alice'));
    final userInstance = personal();
    expect(alias(), same(userInstance));
    expect(userInstance, isNot(same(appInstance)));
    await graph.session().logout();
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
    final graph = _SessionGraph();
    final user = graph.user;
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
    await graph.session().login(_User(1, 'Alice'));
    final oldController = controller();
    final logout = graph.session().logout();
    expect(() => controller(), throwsStateError);
    var resetFinished = false;
    final reset = Scope.cached.reset().then((_) => resetFinished = true);
    final login = graph.session().login(_User(2, 'Bob'));
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
    await graph.session().login(_User(1, 'Alice'));
    final previous = consumer();
    final controller = graph.controller();
    await expectLater(graph.session().logout(), throwsA(same(error)));
    expect(graph.disposed, [controller, controller.accounts]);
    expect(() => consumer(), throwsStateError);

    await graph.session().login(_User(2, 'Bob'));
    expect(consumer(), isNot(same(previous)));
    await expectLater(graph.session().logout(), throwsA(same(error)));
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
    await graph.session().login(_User(1, 'Alice'));
    consumer();
    final controller = graph.controller();
    await graph.session().logout();
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
    await graph.session().login(_User(1, 'Alice'));
    final old = lookup();
    await graph.session().logout();
    final bob = _User(2, 'Bob');
    await graph.session().login(bob);
    final next = lookup();
    final rejected = expectLater(old, throwsStateError);
    gate.complete();
    await rejected;
    expect(await next, same(bob));
  });

  test('overriding a dependency invalidates consumers of its typed view',
      () async {
    final graph = _SessionGraph();
    await graph.session().login(_User(1, 'Alice'));
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
        logout = graph.session().logout();
        return old.accounts.user;
      },
      dependsOn: [graph.controller],
      scope: ScopeType.cached,
      onDispose: graph.disposed.add,
    );
    final alice = _User(1, 'Alice');
    await graph.session().login(alice);
    final controller = graph.controller();
    expect(() => consumer(), throwsStateError);
    await logout;
    expect(graph.disposed, [alice, controller, controller.accounts]);
    expect(() => consumer(), throwsStateError);
  });
}
