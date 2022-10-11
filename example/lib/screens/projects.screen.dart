import 'package:example/domain/project.dart';
import 'package:example/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:managed/managed.dart';
import 'package:mobx/mobx.dart';

import '../app/database/project.dart';
import '../domain/project/state.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends Component<ProjectsScreen> with Managed {
  T _projectState<T extends ProjectState>();

  @override
  void initState() {
    super.initState();
    _projectState().reload();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: _ProjectList(
        _projectState().projectsList,
      ),
    );
  }
}

class _ProjectList extends StatelessObserverWidget {
  final ObservableValue<List<Project>> projects;

  const _ProjectList(this.projects, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: projects.value.length,
      itemBuilder: (context, idx) {
        final project = projects.value[idx];
        return Row(
          key: ValueKey(project.id),
          children: [
            Text(project.title),
          ],
        );
      },
    );
  }
}
