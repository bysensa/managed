import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:managed/annotations.dart';
import 'package:managed_gen/src/extensions/element.extension.dart';
import 'package:managed_gen/src/producers.dart';
import 'package:source_gen/source_gen.dart';

class ProviderProducer extends Producer {
  static final checkerManagedType = TypeChecker.fromRuntime(ManagedType);

  ProviderProducer({
    required this.managedType,
  }) : constructor = managedType.targetConstructor;
  final ClassElement managedType;
  final ConstructorElement constructor;
  late final meta = managedType.managedType!;

  late final parameters = constructor.parameters;

  late final managedParameters = parameters.where((p) => p.isManaged).toList();

  Reference get _on => Reference('Manage<${managedType.displayName}>');

  DartObject? get annotationManagedType => checkerManagedType.firstAnnotationOfExact(
        managedType,
      );

  @override
  Spec produce() {
    final builder = MixinBuilder()
      ..name = managedType.providerMixinName
      ..on = Reference(managedType.manageForClassTypeName)
      ..fields.add(_providerField())
      ..methods.addAll([
        _providerGetter(),
        _constructorMethod(),
        _overrideCallMethod(),
      ]);

    if (meta.scope != ScopeType.unique) {
      builder.fields.add(_paramsField());
    }

    return builder.build();
  }

  Method _constructorMethod() {
    final positional = parameters.where((p) => p.isPositional).map((p) {
      return p.type.element?.isManaged ?? false
          ? refer('Manage.resolve()')
          : refer('zone[#${p.name}]');
    }).toList();

    final named = parameters.where((p) => p.isNamed).map((p) {
      return p.type.element?.isManaged ?? false
          ? MapEntry(p.name, refer('Manage.resolve()'))
          : MapEntry(p.name, refer('zone[#${p.name}]'));
    });

    final builder = MethodBuilder()
      ..name = '_managed'
      ..returns = Reference('${managedType.displayName}')
      ..static = true
      ..body = Block.of([
        Code('final zone = Zone.current;'),
        refer('${managedType.displayName}')
            .newInstance(
              positional,
              Map.fromEntries(named),
            )
            .returned
            .statement,
      ]);

    return builder.build();
  }

  Field _providerField() {
    return Field(
      (b) => b
        ..name = '_provider'
        ..modifier = FieldModifier.final$
        ..static = true
        ..assignment = refer(
          'Manage${managedType.displayName}',
        ).newInstance(
          [
            refer('_managed'),
          ],
          {
            'scope': refer('${meta.scope}'),
            'dependsOn': literalList(_dependsOn()),
          },
        ).code,
    );
  }

  Iterable<Expression> _dependsOn() sync* {
    for (final param in managedParameters) {
      final classElement = param.typeElement as ClassElement;
      yield refer(classElement.providerMixinName).property('provider');
    }
  }

  Method _providerGetter() {
    return Method((b) => b
      ..name = 'provider'
      ..static = true
      ..type = MethodType.getter
      ..returns = _on
      ..body = Block.of([
        ...managedParameters
            .where((p) => p.hasNotUniqueScope)
            .map((p) => p.typeElement)
            .whereType<ClassElement>()
            .map((p) => Code('assert(${p.providerMixinName}.params != null,"");')),
        Code('return _provider;'),
      ]));
  }

  Field _paramsField() {
    return Field(
      (b) => b
        ..name = 'params'
        ..modifier = FieldModifier.var$
        ..type = Reference('${managedType.displayName}Params?')
        ..static = true,
    );
  }

  Method _overrideCallMethod() {
    final builder = MethodBuilder()
      ..name = 'call'
      ..returns = Reference(managedType.displayName)
      ..annotations.add(refer('override'))
      ..optionalParameters.add(
        Parameter(
          (b) => b
            ..name = 'params'
            ..type = Reference('${managedType.displayName}Params?')
            ..covariant = true,
        ),
      )
      ..body = Block.of([
        Code('final ZoneValues values = {};'),
        Code('final deps = {for (final dep in dependencies) dep.managedType: dep};'),
        managedType.isManaged && managedType.hasNotUniqueScope
            ? Code('${managedType.providerMixinName}.params!.inject(values, deps);')
            : Code('params?.inject(values, deps);'),
        Code('values.addEntries(deps.entries.map((e) => MapEntry(e.key, e.value())));'),
        Code('return runZoned(() {'),
        Code('  return callForGenerated();'),
        Code('}, zoneValues: values);'),
      ]);
    return builder.build();
  }
}
