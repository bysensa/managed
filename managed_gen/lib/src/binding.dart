import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'dart_types.dart';
import 'extensions/element.extension.dart';

String bindingName(ClassElement element) =>
    element.managedType!.name ?? element.name;

ClassElement? managedInput(ParameterElement parameter) {
  final type = parameter.type;
  if (type is! InterfaceType) return null;
  final element = type.element;
  return element is ClassElement && element.isManaged ? element : null;
}

class Binding {
  Binding(this.element, this.types, this.package);
  factory Binding.forElement(ClassElement element) => Binding(element,
      DartTypes(), DartTypes.libraryUri(element.library).pathSegments.first);

  final ClassElement element;
  final DartTypes types;
  final String package;
  late final constructor = element.targetConstructor;
  late final name = bindingName(element);
  late final formals = types.formals(element.typeParameters);
  late final arguments = types.arguments(element.thisType.typeArguments);
  late final target = types.render(element.thisType);
  late final scope = element.managedType!.scope;
  bool get generic => element.typeParameters.isNotEmpty;
  late final inputs = _inputs();
  Iterable<Input> get fields => inputs.where((p) => p.hasField);
  late final requiresParams = fields.any((p) => p.requiredInput);

  List<Input> _inputs() {
    final names = {
      for (final p in constructor.parameters)
        if (p.isPublic) p.name
    };
    return [
      for (final (index, p) in constructor.parameters.indexed)
        Input(this, p, index, _parameterName(p, index, names)),
    ];
  }

  String _parameterName(ParameterElement p, int index, Set<String> names) {
    if (p.isNamed && p.isPrivate) {
      throw InvalidGenerationSourceError(
          'Named parameter ${p.name} is private to its library.',
          element: p);
    }
    if (p.isPublic) return p.name;
    var name = p.name.replaceFirst(RegExp('^_+'), '');
    if (name.isEmpty ||
        RegExp(r'^[0-9]').hasMatch(name) ||
        Keyword.keywords.containsKey(name)) {
      name = 'arg$index';
    }
    while (!names.add(name)) {
      name = '${name}_$index';
    }
    return name;
  }

  String generatedName(ClassElement dependency) {
    final owner = DartTypes.libraryUri(dependency.library).pathSegments.first;
    final prefix = owner == package
        ? ''
        : '${types.prefix('package:$owner/module.dart')}.';
    return '$prefix${bindingName(dependency)}';
  }
}

class Input {
  Input(this.binding, this.parameter, this.index, this.name);

  final Binding binding;
  final ParameterElement parameter;
  final int index;
  final String name;
  late final dependency = managedInput(parameter);
  late final keyType =
      '${binding.types.symbol(dependency!)}$dependencyArguments';
  late final nullable =
      binding.element.library.typeSystem.isPotentiallyNullable(parameter.type);

  // A default which cannot be written as a scalar literal may refer to a
  // private const, constructor or function. Let the original constructor apply it.
  late final String? literalDefault = _literal();
  late final bool deferred = !parameter.isRequired &&
      (literalDefault == null ||
          (dependency != null && literalDefault != 'null'));
  bool get hasField =>
      dependency == null || dependency!.hasUniqueScope || deferred;
  // A registration or source can supply a non-nullable dependency even when
  // its original constructor needs arguments. Let that provider validate a miss.
  bool get requiredInput =>
      parameter.isRequired && (dependency == null || nullable);
  bool get sentinel => deferred && nullable;

  String get field {
    const inherited = {
      'targetType',
      'inject',
      'hashCode',
      'runtimeType',
      'toString',
      'noSuchMethod'
    };
    return inherited.contains(name) || name == '${binding.name}Params'
        ? '_field$index'
        : name;
  }

  String get dependencyArguments =>
      binding.types.arguments((parameter.type as InterfaceType).typeArguments);
  String get generated => binding.generatedName(dependency!);
  String get provider => dependencyArguments.isEmpty
      ? '${generated}Provider.provider'
      : '${generated}Provider.of$dependencyArguments()';

  String get fieldType {
    if (dependency != null) return '${generated}Params$dependencyArguments?';
    if (parameter.type is VoidType) return '_core.Object?';
    final type = binding.types.render(parameter.type);
    if (!deferred) return type;
    final library = binding.element.library;
    final acceptsNull = library.typeSystem
        .isSubtypeOf(library.typeProvider.nullType, parameter.type);
    return acceptsNull ? type : '$type?';
  }

  String get present => sentinel ? '_has$index' : 'this.$field != null';

  String? _literal() {
    if (parameter.isRequired) return null;
    final value = parameter.computeConstantValue();
    if (value == null) {
      // An inherited optional super parameter can get its default from a
      // different library. Omitting it is always faithful to Dart.
      if (parameter is SuperFormalParameterElement) return null;
      return parameter.defaultValueCode == null ||
              parameter.defaultValueCode == 'null'
          ? 'null'
          : null;
    }
    if (value.isNull) return 'null';
    // The representation of an extension type can be a scalar without that
    // scalar being assignable to the constructor parameter.
    final library = binding.element.library;
    final core = library.typeProvider;
    String? literal(DartType type, String source) =>
        library.typeSystem.isSubtypeOf(type, parameter.type) ? source : null;
    final string = value.toStringValue();
    if (string != null) return literal(core.stringType, dartString(string));
    final integer = value.toIntValue();
    if (integer != null) return literal(core.intType, integer.toString());
    final boolean = value.toBoolValue();
    if (boolean != null) return literal(core.boolType, boolean.toString());
    final number = value.toDoubleValue();
    if (number == null) return null;
    var source = number.toString();
    if (number.isNaN) source = '_core.double.nan';
    if (number == double.infinity) source = '_core.double.infinity';
    if (number == double.negativeInfinity)
      source = '_core.double.negativeInfinity';
    return literal(core.doubleType, source);
  }
}
