import 'package:colorize_lumberdash/colorize_lumberdash.dart';
import 'package:example/app.dart';
import 'package:example/domain/project.dart';
import 'package:example/module.dart';
import 'package:flutter/cupertino.dart';
import 'package:lumberdash/lumberdash.dart';

void main() {
  putLumberdashToWork(withClients: [ColorizeLumberdash()]);
  AppModule();
  ProjectModule();
  runApp(const ExampleApp());
}
