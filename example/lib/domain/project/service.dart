import 'package:example/app/database.dart';
import 'package:example/app/database/project.dart';
import 'package:example/utils.dart';
import 'package:isar/isar.dart';
import 'package:managed/managed.dart';

class ProjectServiceException implements Exception {}

class ProjectService with Managed {
  T _database<T extends DatabaseProvider>();

  Future<Map<int, Project>> projects() async {
    return await _database()
        .instance
        .map((db) => db.projects)
        .mapAsync(
            (collection) => collection.where().titleIsNotEmpty().findAll())
        .map(
            (projects) => {for (final project in projects) project.id: project})
        .mapErr((err) => ProjectServiceException())
        .unwrap();
  }
}
