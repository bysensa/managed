import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../producers.dart';

class ExtendedManageProducer extends Producer {
  ExtendedManageProducer({
    required this.managedType,
  });

  final ClassElement managedType;

  String get className => managedType.displayName;

  @override
  Spec produce() {
    return Code(
      'class Manage$className = Manage<$className> with ${className}Provider;',
    );
  }
}
