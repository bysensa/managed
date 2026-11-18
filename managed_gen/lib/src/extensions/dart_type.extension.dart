import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

extension DartTypeExt on DartType {
  String get nullabilitySuffixString {
    switch (nullabilitySuffix) {
      case NullabilitySuffix.question:
        return '?';
      default:
        return '';
    }
  }
}
