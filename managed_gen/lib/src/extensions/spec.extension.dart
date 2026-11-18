import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

extension SpecExt on Spec {
  static final _emitter = DartEmitter();
  static final _formatter = DartFormatter();

  String formattedString() => _formatter.format('${accept(_emitter)}');

  String unformattedString() => '${accept(_emitter)}';
}
