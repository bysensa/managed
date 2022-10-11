import 'package:example/app/database.dart';
import 'package:managed/managed.dart';

class AppModule {
  static final database = Manage(DatabaseProvider.new, scope: Scope.singleton);
}
