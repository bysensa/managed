import 'dart:async';

import 'package:managed/managed.dart';
import 'package:test/test.dart';

class _Resource with DependencyLifecycle {
  _Resource({this.start, this.stop});
  final void Function()? start;
  final FutureOr<void> Function()? stop;
  int starts = 0;
  int stops = 0;

  @override
  void init() {
    starts++;
    start?.call();
  }

  @override
  FutureOr<void> dispose() {
    stops++;
    return stop?.call();
  }
}

class _Consumer with DependencyLifecycle {
  _Consumer(this.input);
  final _Resource input;
  int stops = 0;
  @override
  void dispose() => stops++;
}

class _Signal with DependencyLifecycle {}

/// The container of the current user.
class _UserHolder with DependencyLifecycle {
  String? _user = 'alice';
  String get user => _user ?? (throw StateError('Log in first.'));

  Future<void> switchTo(String? next) {
    _user = next;
    return dependencyChanged();
  }
}

class _Repository {
  _Repository(this.user);
  final String user;
  final saved = <String>[];
}

/// Depends on the user and logs out when the session times out. Stream
/// callbacks keep the zone of the factory that subscribed, as Dart zones do
/// for every async callback.
class _SessionWatcher {
  _SessionWatcher(_UserHolder holder, Stream<void> timeouts) {
    timeouts.listen((_) => logout = holder.switchTo(null));
  }

  Future<void>? logout;
}

void main() {
  tearDown(Scope.cached.reset);

  test(
      'a signal evicts its consumers and preserves the publisher and its inputs',
      () async {
    final base = Manage(Object.new, scope: ScopeType.singleton);
    final publisher = Manage<_Resource>(() => _Resource(),
        scope: ScopeType.cached, dependsOn: [base]);
    final global = base();
    final instance = publisher();
    final consumer = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.singleton, dependsOn: [publisher]);
    final old = consumer();
    await instance.dependencyChanged();
    expect(base(), same(global));
    expect(publisher(), same(instance));
    expect(instance.starts, 1);
    expect(instance.stops, 0);
    expect(old.stops, 1);
    final next = consumer();
    expect(next, isNot(same(old)));
    expect(next.input, same(instance));
    await Scope.cached.reset();
    expect(instance.stops, 1);
    expect(next.stops, 1);
    final replacement = consumer();
    await instance.dependencyChanged();
    expect(consumer(), same(replacement));
  });

  test('two owners of different unique instances observe only their own input',
      () async {
    final unique = Manage(() => _Resource());
    final first = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [unique]);
    final second = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [unique]);
    final a = first();
    final b = second();
    final outside = unique();
    await outside.dependencyChanged();
    expect(first(), same(a));
    await a.input.dependencyChanged();
    expect(a.stops, 1);
    expect(a.input.stops, 1);
    expect(second(), same(b));
    final next = first();
    await a.input.dependencyChanged();
    expect(first(), same(next));
    expect(b.stops, 0);
    expect(outside.stops, 0);
    outside.dispose();
  });

  test('a signal discovered after a unique sibling also releases that sibling',
      () async {
    final signal = Manage(_Signal.new, scope: ScopeType.singleton);
    final resource = Manage(() => _Resource());
    final parent = Manage(() => _Consumer(Manage.resolve()),
        dependsOn: [resource, signal]);
    final first = parent();
    await signal().dependencyChanged();
    expect(first.stops, 1);
    expect(first.input.stops, 1);
  });

  test('a diamond through shared cache aliases disposes each instance once',
      () async {
    final log = <String>[];
    _Resource factory() =>
        _Resource(start: () => log.add('+root'), stop: () => log.add('-root'));
    final direct = Scope.cached.provideUsing(factory);
    final left = Manage(factory, scope: ScopeType.cached);
    final right = Manage(factory, scope: ScopeType.cached);
    final leftConsumer = Manage(() => _Resource(stop: () => log.add('-left')),
        scope: ScopeType.singleton, dependsOn: [left]);
    final rightConsumer = Manage(() => _Resource(stop: () => log.add('-right')),
        scope: ScopeType.singleton, dependsOn: [right]);
    final root = Manage(() => _Resource(stop: () => log.add('-consumer')),
        scope: ScopeType.singleton, dependsOn: [leftConsumer, rightConsumer]);
    final old = root();
    expect(left(), same(direct));
    expect(right(), same(direct));
    expect(log, ['+root']);
    await direct.dependencyChanged();
    expect(log, ['+root', '-consumer', '-right', '-left']);
    expect(root(), isNot(same(old)));
    await Scope.cached.reset();
    expect(log, [
      '+root',
      '-consumer',
      '-right',
      '-left',
      '-consumer',
      '-right',
      '-left',
      '-root'
    ]);
  });

  test('an instance supplied as a mock elsewhere keeps its first owner',
      () async {
    final original = Manage(() => _Resource(), scope: ScopeType.cached);
    final other = Manage(() => _Resource(), scope: ScopeType.cached);
    final first = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [original]);
    final second = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [other]);

    final a = first();
    await other.mock(a.input);
    final b = second();
    expect(b.input, same(a.input));

    await a.input.dependencyChanged();
    expect([a.stops, b.stops], [1, 1]);
    expect(a.input.stops, 0);
  });

  test(
      'intrinsic hooks and registration callbacks run in order, even after a disposal error',
      () async {
    final log = <String>[];
    final error = StateError('close failed');
    final gate = Completer<void>();
    final provider = Manage(
        () => _Resource(
            start: () => log.add('init'),
            stop: () async {
              log.add('dispose');
              await gate.future;
              throw error;
            }),
        scope: ScopeType.cached,
        onNewInstance: (_) => log.add('created'),
        onDispose: (_) => log.add('released'));
    final instance = provider();
    expect(provider(), same(instance));
    expect(log, ['init', 'created']);
    final first = expectLater(Scope.cached.reset(), throwsA(same(error)));
    final overlap = expectLater(Scope.cached.reset(), throwsA(same(error)));
    expect(log, ['init', 'created', 'dispose']);
    gate.complete();
    await Future.wait([first, overlap]);
    expect(instance.stops, 1);
    expect(log, ['init', 'created', 'dispose', 'released']);
  });

  test(
      'a failed init evicts the partial instance and cleans its unique input after it',
      () async {
    final gate = Completer<void>();
    final complete = Completer<void>();
    final log = <String>[];
    final error = StateError('init failed');
    var fail = true;
    final input = Manage(() => _Resource(stop: () {
          log.add('input');
          if (!complete.isCompleted) complete.complete();
        }));
    final provider = Manage(
        () => _Resource(start: () {
              if (fail) throw error;
            }, stop: () async {
              log.add('parent');
              await gate.future;
            }),
        scope: ScopeType.cached,
        dependsOn: [input]);
    expect(provider.call, throwsA(same(error)));
    expect(log, ['parent']);
    fail = false;
    final replacement = provider();
    gate.complete();
    await complete.future;
    expect(log, ['parent', 'input']);
    expect(provider(), same(replacement));
    expect(replacement.starts, 1);
  });

  test('a consumer can only read a fully initialized instance', () {
    late Manage<_Resource> publisher;
    late Manage<_Consumer> consumer;
    _Resource? published;
    publisher = Manage(
        () => _Resource(start: () {
              expect(
                  consumer.call,
                  throwsA(isA<StateError>().having(
                      (e) => e.message, 'message', contains('initializing'))));
            }),
        scope: ScopeType.cached,
        onNewInstance: (_) => published = publisher());
    consumer = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [publisher]);
    final ready = publisher();
    expect(published, same(ready));
    expect(consumer().input, same(ready));
  });

  test(
      'a declared unique dependency resolved again inside a factory remains observable',
      () async {
    final events = <String>[];
    final input = Manage(() => _Resource(stop: () => events.add('input')));
    late _Resource extra;
    final provider = Manage(() {
      extra = input();
      return _Consumer(extra);
    },
        scope: ScopeType.cached,
        dependsOn: [input],
        onDispose: (_) => events.add('consumer'));
    final old = provider();
    await extra.dependencyChanged();
    expect(events, ['consumer', 'input', 'input']);
    expect(old.stops, 1);
    expect(provider(), isNot(same(old)));
  });

  test('invalidation during init waits until init returns before disposing',
      () async {
    final events = <String>[];
    late Future<void> reset;
    var invalidate = true;
    final provider = Manage(
        () => _Resource(
            start: () {
              events.add('start');
              if (invalidate) reset = Scope.cached.reset();
              events.add('ready');
            },
            stop: () => events.add('dispose')),
        scope: ScopeType.cached,
        onNewInstance: (_) => events.add('created'));
    expect(provider.call, throwsStateError);
    expect(events, ['start', 'ready']);
    await reset;
    expect(events, ['start', 'ready', 'dispose']);
    invalidate = false;
    expect(provider().starts, 1);
    expect(events.last, 'created');
  });

  test(
      'externally provided mocks can notify consumers and retain ownership of their hooks',
      () async {
    final provider = Manage(() => _Resource(), scope: ScopeType.cached);
    final consumer = Manage(() => _Consumer(Manage.resolve()),
        scope: ScopeType.cached, dependsOn: [provider]);
    final real = provider();
    final mock = _Resource();
    final first = consumer();
    await provider.mock(mock);
    expect(first.stops, 1);
    final second = consumer();
    await real.dependencyChanged();
    expect(consumer(), same(second));
    await mock.dependencyChanged();
    expect(second.stops, 1);
    await provider.resetMock();
    final next = consumer();
    await mock.dependencyChanged();
    expect(consumer(), same(next));
    expect([mock.starts, mock.stops], [0, 0]);
    expect(real.starts, 1);
  });

  test(
      'an unregistered object can signal and a standalone unique resource belongs to its caller',
      () async {
    final plain = _Resource();
    await plain.dependencyChanged();
    final unique = Manage(() => _Resource())();
    expect(unique.starts, 1);
    await unique.dependencyChanged();
    await Scope.cached.reset();
    expect(unique.stops, 0);
    await unique.dispose();
    expect(unique.stops, 1);
  });

  group('a disposer reaches services closer to the root', () {
    late StreamController<void> timeouts;
    late List<String> journal;
    late Manage<_UserHolder> holder;
    late Manage<String> user;
    late Manage<_Repository> repository;
    late Manage<Object> editor;
    late Manage<_SessionWatcher> watcher;

    setUp(() {
      timeouts = StreamController<void>(sync: true);
      journal = [];
      // A fresh closure per test: a shared tear-off would share the singleton.
      holder = Manage(() => _UserHolder(), scope: ScopeType.singleton);
      // Independent of the user, lives for the whole app.
      final storage = Manage(() => journal, scope: ScopeType.singleton);
      user =
          Manage(() => Manage.resolve<_UserHolder>().user, dependsOn: [holder]);
      // Root: depends on the user container.
      repository = Manage(() => _Repository(Manage.resolve()),
          scope: ScopeType.cached, dependsOn: [user]);
      // Leaf: its cleanup uses its input and an unrelated service.
      editor = Manage(Object.new,
          scope: ScopeType.cached,
          dependsOn: [repository],
          onDispose: (_) {
            repository().saved.add('draft');
            storage().add('editor closed');
          });
      watcher = Manage(
          () => _SessionWatcher(Manage.resolve(), timeouts.stream),
          scope: ScopeType.cached,
          dependsOn: [holder]);
    });

    tearDown(() async {
      await Scope.cached.reset().catchError((_) {});
      // close() completes only after a listener receives done; do not await.
      unawaited(timeouts.close());
    });

    test('the UI switches the user: the draft goes to the old repository',
        () async {
      final old = repository();
      editor();
      await holder().switchTo('bob');
      expect({'alice': old.saved, 'bob': repository().saved}, {
        'alice': ['draft'],
        'bob': <String>[],
      });
    });

    test('the UI logs out: the draft goes to the old repository', () async {
      final old = repository();
      editor();
      await holder().switchTo(null);
      expect(old.saved, ['draft']);
    });

    test('the watcher logs out on timeout: the cleanup still reaches services',
        () async {
      final w = watcher();
      final old = repository();
      editor();
      timeouts.add(null);
      await w.logout;
      expect(old.saved, ['draft']);
      expect(journal, ['editor closed']);
    });

    test('an input cannot reach a consumer already released by the cleanup',
        () async {
      late Manage<Object> consumer;
      final input = Manage(() => Object(),
          scope: ScopeType.cached,
          dependsOn: [user],
          onDispose: (_) => consumer());
      consumer = Manage(Object.new, scope: ScopeType.cached, dependsOn: [input]);
      consumer();
      await expectLater(holder().switchTo('bob'), throwsStateError);
    });
  });
}
