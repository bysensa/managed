import 'package:example/domain/project/model.dart';
import 'package:managed/managed.dart';

import 'service.dart';

class ProjectState with Managed, ProjectStateModel {
  T _service<T extends ProjectService>();

  Future<void> reload() async {
    final persistedProjects = await _service().projects();
    projects.addAll(persistedProjects);
  }
}
