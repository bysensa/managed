import 'package:colorize_lumberdash/colorize_lumberdash.dart';
import 'package:example/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:lumberdash/lumberdash.dart';

void main() {
  putLumberdashToWork(withClients: [ColorizeLumberdash()]);
  runApp(const ExampleApp());
}
