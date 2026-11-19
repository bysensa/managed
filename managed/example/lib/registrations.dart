import 'package:managed/managed.dart';

import 'markdown.dart';
import 'module.dart';
import 'notebook.dart';

abstract final class AppModule {
  static final storage = Manage<NoteStorage>(
    MemoryStorage.new,
    scope: ScopeType.singleton,
  );

  static final helpCache = Manage(
    TextCache.new,
    scope: ScopeType.cached,
  );
}

abstract final class AuthModule {
  static final session = Manage(UserSession.new, scope: ScopeType.singleton);
  static final user = Manage(
    () => Manage.resolve<UserSession>().user,
    dependsOn: [session],
  );
}

abstract final class NotesModule {
  static final cache = Manage(
    TextCache.new,
    scope: ScopeType.cached,
    // Записи в кэше принадлежат конкретной паре аккаунта и хранилища.
    dependsOn: [AuthModule.user, AppModule.storage],
  );

  static final repository = Manage(
    () => CachedNotebook(
      Manage.resolve<User>(),
      Manage.resolve<NoteStorage>(),
      Manage.resolve<TextCache>(),
    ),
    scope: ScopeType.cached,
    dependsOn: [AuthModule.user, AppModule.storage, cache],
  );

  static final notebook = repository.as<Notebook>();
}

abstract final class EditorModule {
  // Скоуп по умолчанию — unique. Каждый редактор получает свой буфер.
  static final buffer = Manage(DraftBuffer.new);

  static final editor = Manage(
    () => NoteEditor(Manage.resolve<Notebook>(), Manage.resolve<DraftBuffer>()),
    scope: ScopeType.singleton,
    dependsOn: [NotesModule.notebook, buffer],
  );
}

abstract final class ExportModule {
  static void configure({required String headingPrefix}) {
    MarkdownStyleProvider.params =
        MarkdownStyleParams(headingPrefix: headingPrefix);
  }

  /// Each export creates its own unique registration. The arguments are
  /// captured by the factory closure; `dependsOn` supplies the user and notebook.
  static Future<String> markdown(
    String key, {
    required String title,
    bool includeAuthor = true,
  }) {
    final template = MarkdownTemplateProvider.register(
      params: MarkdownTemplateParams(
        heading: MarkdownHeadingParams(title: title),
        includeAuthor: includeAuthor,
      ),
    );
    return Manage<Future<String>>(
      () async {
        final notebook = Manage.resolve<Notebook>();
        final template = Manage.resolve<MarkdownTemplate>();
        final body = await notebook.read(key);
        // После await resolve проверит, действует ли сессия этого экспорта.
        final author = Manage.resolve<User>();
        if (body == null) throw StateError('Заметка «$key» не найдена');
        return template.render(body, author.name);
      },
      dependsOn: [AuthModule.user, NotesModule.notebook, template],
    )();
  }
}
