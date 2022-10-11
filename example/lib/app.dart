import 'package:example/screens/projects.screen.dart';
import 'package:flutter/cupertino.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: const ProjectsScreen(),
    );
  }
}
