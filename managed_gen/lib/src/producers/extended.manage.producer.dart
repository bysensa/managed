import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../binding.dart';
import '../producers.dart';

class ExtendedManageProducer extends Producer {
  ExtendedManageProducer({required ClassElement managedType})
      : this.forBinding(Binding.forElement(managedType));
  ExtendedManageProducer.forBinding(this.binding);
  final Binding binding;

  @override
  Spec produce() => Code('class Manage${binding.name}${binding.formals} = '
      '_m.Manage<${binding.target}> with ${binding.name}Provider${binding.arguments};');
}
