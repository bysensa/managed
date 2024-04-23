import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:code_builder/code_builder.dart';
import 'package:managed_gen/managed_gen.dart';
import 'package:managed_gen/src/extensions/dart_type.extension.dart';
import 'package:managed_gen/src/extensions/element.extension.dart';
import 'package:managed_gen/src/model/managed_type_meta.dart';

class ParamsProducer extends Producer {
  ParamsProducer({
    required this.managedType,
  }) : constructor = managedType.targetConstructor;

  final ClassElement managedType;
  final ConstructorElement constructor;

  late final parameters = constructor.parameters;
  late final targetParameters = parameters
      .where((p) => p.hasNotSingletonScope)
      .where((p) => p.hasNotCachedScope)
      .toList();

  @override
  Spec produce() {
    final builder = ClassBuilder()
      ..name = managedType.paramsClassName
      ..extend = Reference('Params')
      ..constructors.add(_constructor())
      ..fields.addAll(_fields())
      ..methods.addAll([_typeGetter(), _injectMethod()]);
    return builder.build();
  }

  Constructor _constructor() {
    final builder = ConstructorBuilder()
      ..optionalParameters.addAll(_constructorParameters());
    return builder.build();
  }

  Iterable<Parameter> _constructorParameters() sync* {
    for (final param in targetParameters) {
      final parameter = Parameter(
        (b) => b
          ..name = param.name
          ..required = param.isRequired
          ..named = true
          ..toThis = true,
      );
      yield parameter;
    }
  }

  Iterable<Field> _fields() sync* {
    for (final param in targetParameters) {
      final nullabilitySuffix = param.type.nullabilitySuffixString;
      final paramTypeElement = param.typeElement;
      final field = Field(
        (b) => b
          ..name = param.name
          ..type = paramTypeElement?.isNotManaged ?? false
              ? Reference(param.type.getDisplayString(withNullability: true))
              : Reference('${param.typeElement?.displayName}Params$nullabilitySuffix')
          ..modifier = FieldModifier.final$,
      );
      yield field;
    }
  }

  Method _typeGetter() {
    final builder = MethodBuilder()
      ..name = 'targetType'
      ..returns = Reference('Type')
      ..type = MethodType.getter
      ..annotations.addAll([refer('override')])
      ..lambda = true
      ..body = Code(managedType.displayName);
    return builder.build();
  }

  Method _injectMethod() {
    final builder = MethodBuilder()
      ..name = 'inject'
      ..annotations.addAll([refer('override')])
      ..requiredParameters.addAll([
        Parameter(
          (b) => b
            ..name = 'values'
            ..type = Reference('ZoneValues'),
        ),
        Parameter(
          (b) => b
            ..name = 'dependencies'
            ..type = Reference('Map<Type, Manage>'),
        ),
      ])
      ..returns = Reference('void')
      ..body = Block.of(
        [
          for (final param in targetParameters)
            param.isManaged
                ? Code(
                    'values[${param.name}.targetType] = dependencies.remove(${param.name}.targetType)?.call(${param.name});')
                : Code("values[#${param.name}] = ${param.name};"),
        ],
      );
    return builder.build();
  }
}
