import 'package:managed/managed.dart';
import 'package:managed_notebook_example/notebook.dart';
import 'package:managed_notebook_example/registrations.dart';

const route = 'route';

/// Провайдер открывает блокнот того пользователя, который сейчас вошёл.
Future<void> showRoute(Provider<Notebook> openNotebook) async {
  final text = await openNotebook().read(route);
  print('  ${AuthModule.user().name} видит «${text ?? 'пока пусто'}»');
}

Future<void> main(List<String> arguments) async {
  ExportModule.configure(headingPrefix: '##');
  if (arguments.contains('--graph')) {
    printGraph(
        {AppModule.helpCache, EditorModule.editor, ExportModule.markdown});
    return;
  }
  try {
    await runNotebook();
  } finally {
    await AuthModule.session().logout();
    await Scope.cached.reset();
  }
}

void printGraph(ManagedBy roots) {
  final seen = <Manage>{};
  void visit(Manage provider, String indent) {
    final scope = provider.scope.name;
    final firstVisit = seen.add(provider);
    print('$indent${provider.managedType} [$scope]${firstVisit ? '' : ' ↩'}');
    if (firstVisit) {
      for (final dependency in provider.dependencies) {
        visit(dependency, '$indent  ');
      }
    }
  }

  for (final root in roots) {
    visit(root, '');
  }
}

Future<void> runNotebook() async {
  print('Гость открывает справку');
  final storage = AppModule.storage();
  final help = AppModule.helpCache()..put('save', 'Ctrl+S');
  final direct = Scope.cached.provideUsing(TextCache.new);
  print('  Справка через модуль и через Scope — '
      '${instanceName(help)} и ${instanceName(direct)}');
  try {
    EditorModule.editor();
  } on StateError catch (error) {
    print('  Редактор недоступен — ${error.message}');
  }

  print('\nАнна открывает блокнот');
  await AuthModule.session().login(const User('anna', 'Анна'));
  final editor = EditorModule.editor();
  final repository = NotesModule.repository();
  print(
      '  Та же фабрика TextCache.new создала личный ${instanceName(NotesModule.cache())}');
  print('  Интерфейс Notebook и конкретный репозиторий — '
      '${instanceName(editor.notebook)} и ${instanceName(repository)}');
  editor.edit(route, 'Поезд до Выборга');
  await editor.save();

  print('\nС сервера приходит новая фамилия');
  await AuthModule.session().login(const User('anna', 'Анна Волкова'));
  print('  В сессии — ${AuthModule.user().name}, '
      'в снимке при открытии блокнота — ${repository.owner.name}');
  print('  Редактор до и после обновления — '
      '${instanceName(editor)} и ${instanceName(EditorModule.editor())}');
  print(await ExportModule.markdown(ExportNoteParams(route, title: 'Маршрут')));

  print('\nАнна сбрасывает кэш с несохранённой правкой');
  editor.edit(route, 'Поезд до Выборга в 09:30');
  ExportModule.configure(headingPrefix: '#');
  await Scope.cached.reset();
  final reopened = EditorModule.editor();
  print('  Сессия ${AuthModule.user().id}, редактор ${instanceName(reopened)}, '
      'хранилище ${instanceName(AppModule.storage())}');
  print(await ExportModule.markdown(
    ExportNoteParams(route, title: 'Уточнённый маршрут', includeAuthor: false),
  ));
  final newHelp = AppModule.helpCache()..put('save', 'Ctrl+S');

  print('\nБорис входит, пока у Анны открыт черновик');
  reopened.edit(route, 'Встречаемся у первого вагона');
  const boris = User('boris', 'Борис');
  await AuthModule.session().login(boris);
  print('  На сервере у Анны — «${await storage.read('anna', route)}»');
  await showRoute(NotesModule.notebook);
  final borisEditor = EditorModule.editor();
  borisEditor.edit(route, 'Автобус до Пскова');

  print('\nБорис выходит и снова входит в тот же аккаунт');
  await AuthModule.session().logout();
  print('  После выхода общая справка ${instanceName(newHelp)} по-прежнему '
      'хранит ${newHelp.read('save')}');
  await AuthModule.session().login(boris);
  print('  Редактор в предыдущем и новом входе — '
      '${instanceName(borisEditor)} и ${instanceName(EditorModule.editor())}');
  await showRoute(NotesModule.notebook);
}
