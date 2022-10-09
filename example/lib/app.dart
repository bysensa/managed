import 'package:example/app/permission_check.dart';
import 'package:flutter/cupertino.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      builder: (context, child) => PermissionCheck(
        child: child,
      ),
    );
  }
}
