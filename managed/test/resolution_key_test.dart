import 'package:managed/managed.dart';
import 'package:test/test.dart';

class TextCache {
  TextCache(this.owner);
  final String owner;
}

class Pair {
  Pair(this.help, this.user);
  final TextCache help;
  final TextCache user;
}

class Box {}

enum Slot { help, user }

abstract final class _AppModule {}

class _Signal with DependencyLifecycle {}

void main() {
  tearDown(Scope.cached.reset);

  late Manage<_Signal> signal;
  late Manage<TextCache> help;
  late Manage<TextCache> user;

  setUp(() {
    signal = Manage(() => _Signal(), scope: ScopeType.singleton);
    help = Manage(() => TextCache('help'),
        scope: ScopeType.cached, resolutionKey: Slot.help);
    user = Manage(() => TextCache('user'),
        scope: ScopeType.cached,
        dependsOn: [signal],
        resolutionKey: Slot.user);
  });

  test('inputs of one type are selected by their resolution keys', () {
    final pair = Manage(() => Pair(resolve(Slot.help), resolve(Slot.user)),
        dependsOn: [help, user]);
    final value = pair();
    expect(value.help, same(help()));
    expect(value.user, same(user()));
  });

  test('a key can be any object, e.g. a module type or a string', () {
    final app = Manage(() => TextCache('app'),
        scope: ScopeType.cached, resolutionKey: _AppModule);
    final notes = Manage(() => TextCache('notes'),
        scope: ScopeType.cached, resolutionKey: 'notes');
    final owners = Manage(
        () => [
              Manage.resolve<TextCache>(_AppModule).owner,
              Manage.resolve<TextCache>('notes').owner,
            ],
        dependsOn: [app, notes]);
    expect(owners(), ['app', 'notes']);
  });

  test('a lookup without a key still finds an input by its type', () {
    final single = Manage(() => resolve<TextCache>(), dependsOn: [help]);
    expect(single(), same(help()));
  });

  test('a missing key fails and names the key', () {
    final missing =
        Manage(() => resolve<TextCache>(Slot.user), dependsOn: [help]);
    expect(
        missing.call,
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('Slot.user'))));
  });

  test('registrations that differ only by key keep separate instances', () {
    final first = Manage(Box.new,
        scope: ScopeType.cached, resolutionKey: Slot.help);
    final second = Manage(Box.new,
        scope: ScopeType.cached, resolutionKey: Slot.user);
    expect(first(), isNot(same(second())));
    // Without a key the factory is still shared within the scope.
    expect(Manage(Box.new, scope: ScopeType.cached)(),
        same(Scope.cached.provideUsing(Box.new)));
  });

  test('a typed view keeps the key of its registration', () {
    final view = help.as<Object>();
    expect(view.resolutionKey, Slot.help);
    final holder =
        Manage(() => [resolve<Object>(Slot.help)], dependsOn: [view]);
    expect(holder().single, same(help()));
  });

  test('a nested factory finds a keyed input of the enclosing factory', () {
    final inner = Manage(() => resolve<TextCache>(Slot.user));
    final outer = Manage(() => inner(), dependsOn: [help, user]);
    expect(outer(), same(user()));
  });

  test('a change of a keyed input recreates its consumer', () async {
    final pair = Manage(() => Pair(resolve(Slot.help), resolve(Slot.user)),
        scope: ScopeType.singleton, dependsOn: [help, user]);
    final first = pair();
    await signal().dependencyChanged();
    final next = pair();
    expect(next, isNot(same(first)));
    expect(next.help, same(first.help));
    expect(next.user, isNot(same(first.user)));
  });

  test('resolve and Manage.resolve return the same input', () {
    final both = Manage(
        () => identical(resolve<TextCache>(Slot.help),
            Manage.resolve<TextCache>(Slot.help)),
        dependsOn: [help]);
    expect(both(), isTrue);
  });
}
