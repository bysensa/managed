import 'package:example/app/database/project.dart';
import 'package:example/utils.dart';
import 'package:mobx/mobx.dart';

export 'package:example/app/database/project.dart';

mixin ProjectStateModel {
  final projects = ObservableMap<int, Project>();
  final selectedProjectId = Observable<Option<int>>(const None());

  late final selectedProject = Computed(() {
    return Option.from(projects[selectedProjectId.value.toNullable()]);
  });

  late final projectsList = Computed(() => projects.values.toList());
}
