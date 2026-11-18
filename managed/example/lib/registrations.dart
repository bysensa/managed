import 'dart:async';

import 'package:managed/managed.dart';

import 'markdown.dart';
import 'module.dart';
import 'notebook.dart';

final _ids = Expando<int>();
var _nextId = 0;

/// По номеру в журнале можно проследить за конкретным экземпляром.
String instanceName(Object value) =>
    '${value.runtimeType}#${_ids[value] ??= ++_nextId}';

void _created(Object value) => print('  + ${instanceName(value)}');
void _disposed(Object value) => print('  − ${instanceName(value)}');

void _closeCache(TextCache cache) {
  cache.close();
  _disposed(cache);
}

abstract final class AppModule {
  static final storage = Manage<NoteStorage>(
    MemoryStorage.new,
    scope: ScopeType.singleton,
    onNewInstance: _created,
  );

  static final helpCache = Manage(
    TextCache.new,
    scope: ScopeType.cached,
    onNewInstance: _created,
    onDispose: _closeCache,
  );
}

abstract final class AuthModule {
  static final user = Manage.source<User>(
    sameIdentity: (previous, next) => previous.id == next.id,
    onDispose: (user) => print('  − сессия ${user.name} (${user.id})'),
  );
}

abstract final class NotesModule {
  static final cache = Manage(
    TextCache.new,
    scope: ScopeType.cached,
    // Записи в кэше принадлежат конкретной паре аккаунта и хранилища.
    dependsOn: [AuthModule.user, AppModule.storage],
    onNewInstance: _created,
    onDispose: _closeCache,
  );

  static final repository = Manage(
    () => CachedNotebook(
      Manage.resolve<User>(),
      Manage.resolve<NoteStorage>(),
      Manage.resolve<TextCache>(),
    ),
    scope: ScopeType.cached,
    dependsOn: [AuthModule.user, AppModule.storage, cache],
    onNewInstance: _created,
    onDispose: (repo) {
      repo.close();
      _disposed(repo);
    },
  );

  static final notebook = repository.as<Notebook>();
}

abstract final class EditorModule {
  // Скоуп по умолчанию — unique. Каждый редактор получает свой буфер.
  static final buffer = Manage(
    DraftBuffer.new,
    onNewInstance: _created,
    onDispose: (drafts) {
      drafts.close();
      _disposed(drafts);
    },
  );

  static final editor = Manage(
    () => NoteEditor(Manage.resolve<Notebook>(), Manage.resolve<DraftBuffer>()),
    scope: ScopeType.singleton,
    dependsOn: [NotesModule.notebook, buffer],
    onNewInstance: _created,
    onDispose: (editor) async {
      // Пока сохраняется черновик, буфер и репозиторий ещё открыты.
      await editor.close();
      _disposed(editor);
    },
  );
}

class ExportNoteParams extends Params {
  ExportNoteParams(this.key, {required this.title, this.includeAuthor = true});

  final String key;
  final String title;
  final bool includeAuthor;

  @override
  Type get targetType => Future<String>;

  @override
  void inject(ZoneValues values, Map<Type, Manage> dependencies) {
    values[#noteKey] = key;
    final params = MarkdownTemplateParams(
      heading: MarkdownHeadingParams(title: title),
      includeAuthor: includeAuthor,
    );
    // Для шаблона нужны параметры. Оставшиеся регистрации пользователя
    // и блокнота Manage вызовет сам.
    final template = dependencies.remove(MarkdownTemplate)!;
    values[MarkdownTemplate] = template(params);
  }
}

abstract final class ExportModule {
  static void configure({required String headingPrefix}) {
    MarkdownStyleProvider.params =
        MarkdownStyleParams(headingPrefix: headingPrefix);
  }

  static final markdown = Manage<Future<String>>(
    () async {
      final key = Zone.current[#noteKey] as String;
      final notebook = Manage.resolve<Notebook>();
      final template = Manage.resolve<MarkdownTemplate>();
      final body = await notebook.read(key);
      // После await resolve проверит, действует ли сессия этого экспорта.
      final author = Manage.resolve<User>();
      if (body == null) throw StateError('Заметка «$key» не найдена');
      return template.render(body, author.name);
    },
    dependsOn: [
      AuthModule.user,
      NotesModule.notebook,
      MarkdownTemplateProvider.provider,
    ],
  );
}
