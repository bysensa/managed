import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../binding.dart';
import '../producers.dart';

class ParamsProducer extends Producer {
  ParamsProducer({required ClassElement managedType})
      : this.forBinding(Binding.forElement(managedType));
  ParamsProducer.forBinding(this.binding);
  final Binding binding;

  @override
  Spec produce() {
    final b = binding;
    final fields = b.fields.toList();
    final formals = <String>[];
    final initializers = <String>[];
    final declarations = StringBuffer();
    for (final p in fields) {
      if (p.sentinel) {
        formals.add('_core.Object? ${p.name} = _omitted');
        final omitted = '_core.identical(${p.name}, _omitted)';
        final type = p.fieldType;
        final value = type == '_core.Object?' || type == 'dynamic'
            ? p.name
            : '${p.name} as $type';
        initializers.add('_has${p.index} = !$omitted');
        initializers.add('${p.field} = $omitted ? null : $value');
        declarations.writeln('final _core.bool _has${p.index};');
        declarations.writeln('final $type ${p.field};');
        continue;
      }
      final required = p.requiredInput ? 'required ' : '';
      final defaultValue = p.dependency == null &&
              p.literalDefault != null &&
              p.literalDefault != 'null'
          ? ' = ${p.literalDefault}'
          : '';
      final formal =
          p.field == p.name ? 'this.${p.name}' : '${p.fieldType} ${p.name}';
      if (p.field != p.name) initializers.add('${p.field} = ${p.name}');
      formals.add('$required$formal$defaultValue');
      declarations.writeln('final ${p.fieldType} ${p.field};');
    }
    final parameters = formals.isEmpty ? '' : '{${formals.join(', ')}}';
    final init = initializers.isEmpty ? '' : ': ${initializers.join(', ')}';
    final out = StringBuffer()
      ..writeln('class ${b.name}Params${b.formals} extends _m.Params {')
      ..writeln('${b.name}Params($parameters) $init;')
      ..write(declarations)
      ..writeln('@_core.override _core.Type get targetType => ${b.target};')
      ..writeln(
          '@_core.override void inject(_m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {');

    final expressions = <String>[];
    final keys = <String>{};
    for (final p in b.inputs) {
      if (p.dependency == null) {
        // Custom ManageFoo factories can read the original parameter symbols.
        // The generated constructor uses its own typed arguments below.
        final guard = p.deferred ? 'if (${p.present}) ' : '';
        out.writeln('${guard}values[#${p.name}] = this.${p.field};');
        expressions.add('this.${p.field}');
        continue;
      }
      keys.add(p.keyType);
      final arg = p.hasField ? 'this.${p.field}' : '';
      final provider = 'dependencies[${p.keyType}]!';
      var expression = '$provider($arg) as ${p.keyType}';
      if (p.hasField && p.nullable)
        expression = '$arg == null ? null : $expression';
      if (p.deferred) expression = '${p.present} ? ($expression) : null';
      final local = '_input${p.index}';
      out.writeln('final $local = $expression;');
      out.writeln('values[${p.keyType}] = $local;');
      expressions.add(local);
    }
    // Fetch before removing: two occurrences of the same type may require
    // different arguments, even when T and U happen to be equal at runtime.
    for (final key in keys) {
      out.writeln('dependencies.remove($key);');
    }
    final ctor = b.constructor.name.isEmpty
        ? b.target
        : '${b.target}.${b.constructor.name}';
    final invocation = b.inputs.any((p) => p.deferred)
        ? _apply(ctor, expressions)
        : '$ctor(${b.inputs.map((p) => '${p.parameter.isNamed ? '${p.parameter.name}: ' : ''}${expressions[p.index]}').join(', ')})';
    out.writeln('values[${b.name}Params${b.arguments}] = () => $invocation;');
    out.writeln('}}');
    return Code(out.toString());
  }

  String _apply(String constructor, List<String> expressions) {
    final positional = <String>[];
    final named = <String>[];
    final defaults = <String>[];
    for (final p in binding.inputs) {
      final expression = expressions[p.index];
      if (p.parameter.isNamed) {
        final guard = p.deferred ? 'if (${p.present}) ' : '';
        named.add('$guard#${p.parameter.name}: $expression');
      } else if (p.deferred) {
        positional.add('${p.present} ? $expression : _omitted');
      } else if (p.parameter.isOptionalPositional && p.literalDefault != null) {
        defaults.add('${positional.length}: ${p.literalDefault}');
        positional.add(
            '_core.identical($expression, ${p.literalDefault}) ? _omitted : $expression');
      } else {
        positional.add(expression);
      }
    }
    final tearOff =
        binding.constructor.name.isEmpty ? '$constructor.new' : constructor;
    return '_invoke<${binding.target}>($tearOff, [${positional.join(', ')}], {${named.join(', ')}}, {${defaults.join(', ')}})';
  }
}
