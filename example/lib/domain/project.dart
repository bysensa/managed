import 'package:example/domain/project/service.dart';
import 'package:example/domain/project/state.dart';
import 'package:example/module.dart';
import 'package:managed/managed.dart';

class ProjectModule {
  final provides = {projectState};

  static final projectService = Manage(
    ProjectService.new,
    scope: Scope.singleton,
    dependsOn: [AppModule.database],
  );

  static final projectState = Manage(
    ProjectState.new,
    scope: Scope.singleton,
    dependsOn: [projectService],
  );
}
