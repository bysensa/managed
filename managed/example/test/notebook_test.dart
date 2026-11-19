import 'dart:async';

import 'package:managed/managed.dart';
import 'package:managed_notebook_example/module.dart';
import 'package:managed_notebook_example/notebook.dart';
import 'package:managed_notebook_example/registrations.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => ExportModule.configure(headingPrefix: '##'));
  tearDown(() async {
    await AuthModule.session().logout();
    await AppModule.storage.resetMock();
    await Scope.cached.reset();
  });

  test(
      'обновление профиля сохраняет редактор, смена аккаунта сохраняет черновик',
      () async {
    final help = AppModule.helpCache();
    expect(Scope.cached.provideUsing(TextCache.new), same(help));
    expect(() => EditorModule.editor(), throwsStateError);
    const anna = User('session-anna', 'Анна');
    await AuthModule.session().login(anna);
    final editor = EditorModule.editor();
    final repo = NotesModule.repository();
    expect(editor.notebook, same(repo));
    expect(NotesModule.cache(), isNot(same(help)));
    editor.edit('plan', 'Музей');

    const updated = User('session-anna', 'Анна Волкова');
    await AuthModule.session().login(updated);
    expect(EditorModule.editor(), same(editor));
    expect(AuthModule.user(), same(updated));
    expect(repo.owner, same(anna));

    const boris = User('session-boris', 'Борис');
    await AuthModule.session().login(boris);
    expect(await AppModule.storage().read(anna.id, 'plan'), 'Музей');
    expect(() => editor.edit('plan', 'Опоздавшая правка'), throwsStateError);
    expect(await NotesModule.notebook().read('plan'), isNull);
    final next = EditorModule.editor()..edit('plan', 'Парк');
    await AuthModule.session().logout();
    expect(() => NotesModule.notebook(), throwsStateError);
    expect(AppModule.helpCache(), same(help));

    await AuthModule.session().login(boris);
    expect(EditorModule.editor(), isNot(same(next)));
    expect(await NotesModule.notebook().read('plan'), 'Парк');
  });

  test('сброс кэша закрывает редактор и его буфер при активной сессии',
      () async {
    const user = User('reset', 'Вера');
    await AuthModule.session().login(user);
    final storage = AppModule.storage();
    final editor = EditorModule.editor()..edit('list', 'Купить хлеб');
    final privateCache = NotesModule.cache();
    final sameBinding = Manage(TextCache.new,
        scope: ScopeType.cached,
        dependsOn: [AuthModule.user, AppModule.storage]);
    expect(sameBinding(), same(privateCache));
    final scratch = EditorModule.buffer()..edits['scratch'] = 'Отдельный буфер';
    addTearDown(scratch.dispose);
    await Scope.unique.reset();
    await Scope.singleton.reset();
    expect(EditorModule.editor(), same(editor));

    await Scope.cached.reset();
    expect(AuthModule.user(), same(user));
    expect(AppModule.storage(), same(storage));
    expect(await storage.read(user.id, 'list'), 'Купить хлеб');
    expect(() => privateCache.read('list'), throwsStateError);
    final reopened = EditorModule.editor();
    expect(reopened, isNot(same(editor)));
    expect(reopened.buffer, isNot(same(editor.buffer)));
    expect(scratch.edits['scratch'], 'Отдельный буфер');
  });

  test('mock и resetMock переключают хранилище вместе с его потребителями',
      () async {
    const user = User('storage-test', 'Олег');
    await AuthModule.session().login(user);
    final original = AppModule.storage();
    final first = EditorModule.editor()..edit('first', 'Оригинал');
    final fake = MemoryStorage();
    await AppModule.storage.mock(fake);
    expect(await original.read(user.id, 'first'), 'Оригинал');
    final replacement = EditorModule.editor()
      ..edit('second', 'Только для теста');
    expect(replacement, isNot(same(first)));

    await AppModule.storage.resetMock();
    expect(await fake.read(user.id, 'second'), 'Только для теста');
    expect(AppModule.storage(), same(original));
    expect(EditorModule.editor(), isNot(same(replacement)));
    expect(await NotesModule.notebook().read('second'), isNull);
  });

  test('при одновременных logout и reset сбой записи приходит обоим вызовам',
      () async {
    final storage = PausedWriteStorage();
    await AppModule.storage.mock(storage);
    await AuthModule.session().login(const User('offline', 'Маша'));
    final editor = EditorModule.editor()..edit('draft', 'Черновик');
    final cache = NotesModule.cache();
    final failure = StateError('Хранилище недоступно');

    final save = expectLater(editor.save(), throwsA(same(failure)));
    await storage.started.future;
    final logout =
        expectLater(AuthModule.session().logout(), throwsA(same(failure)));
    final reset = expectLater(Scope.cached.reset(), throwsA(same(failure)));
    expect(() => EditorModule.editor(), throwsStateError);
    storage.result.completeError(failure);
    await Future.wait([save, logout, reset]);

    expect(storage.attempts, 1);
    expect(() => cache.read('draft'), throwsStateError);
  });

  test('сгенерированные Params передают заголовок на вызов и стиль на весь кэш',
      () async {
    final template = MarkdownTemplateProvider.provider;
    final first = template(MarkdownTemplateParams(
      heading: MarkdownHeadingParams(title: 'План'),
      includeAuthor: true,
    ));
    ExportModule.configure(headingPrefix: '#');
    final params = MarkdownTemplateParams(
      heading: MarkdownHeadingParams(title: 'Список'),
      includeAuthor: false,
    );
    final second = template(params);
    expect(first.heading, isNot(same(second.heading)));
    expect(first.style, same(second.style));
    expect(first.render('Чай', 'Ира'), '## План\n\nЧай\n\n— Ира');
    expect(second.render('Чай', 'Ира'), '## Список\n\nЧай');

    await Scope.cached.reset();
    expect(template(params).render('Чай', 'Ира'), '# Список\n\nЧай');
  });

  test(
      'экспорт, начатый до смены аккаунта, не подпишется именем нового пользователя',
      () async {
    final storage = PausedStorage();
    await AppModule.storage.mock(storage);
    await storage.write('export-anna', 'route', 'Поезд');
    await storage.write('export-boris', 'route', 'Автобус');
    await AuthModule.session().login(const User('export-anna', 'Анна'));
    final params = ExportNoteParams('route', title: 'Маршрут');
    final oldExport = ExportModule.markdown(params);
    final rejected = expectLater(oldExport, throwsStateError);

    await storage.started.future;
    await AuthModule.session().login(const User('export-boris', 'Борис'));
    storage.resume.complete();
    await rejected;
    expect(await ExportModule.markdown(params),
        '## Маршрут\n\nАвтобус\n\n— Борис');
  });
}

class PausedStorage extends MemoryStorage {
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<String?> read(String owner, String key) async {
    if (!started.isCompleted) started.complete();
    await resume.future;
    return super.read(owner, key);
  }
}

class PausedWriteStorage extends MemoryStorage {
  final started = Completer<void>();
  final result = Completer<void>();
  int attempts = 0;

  @override
  Future<void> write(String owner, String key, String text) {
    attempts++;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}
