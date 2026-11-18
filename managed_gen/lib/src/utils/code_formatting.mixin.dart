import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

mixin CodeFormattingMixin {
  final _emitter = DartEmitter();
  final _formatter = DartFormatter();

  String formatted(Spec code) => _formatter.format('${code.accept(_emitter)}');

  String unformatted(Spec code) => '${code.accept(_emitter)}';
}
