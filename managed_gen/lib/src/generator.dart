import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'binding.dart';
import 'dart_types.dart';
import 'producers/extended.manage.producer.dart';
import 'producers/params.producer.dart';
import 'producers/provider.producer.dart';

class ManagedGenerator {
  ManagedGenerator(this.package);
  final String package;

  String generate(Iterable<ClassElement> roots,
      {void Function(ClassElement)? onExternal}) {
    const header = '// GENERATED CODE - DO NOT MODIFY BY HAND\n';
    if (roots.isEmpty) return header;
    final types = DartTypes();
    final bindings = <Binding>[];
    final seen = <ClassElement>{};
    final path = <ClassElement>[];
    final symbols = <String, ClassElement>{};
    void visit(ClassElement element) {
      final cycle = path.indexOf(element);
      if (cycle != -1) {
        throw InvalidGenerationSourceError(
          'Circular managed dependency: ${[
            ...path.skip(cycle),
            element
          ].map((e) => e.name).join(' -> ')}.',
          element: element,
        );
      }
      if (!seen.add(element)) return;
      if (DartTypes.libraryUri(element.library).pathSegments.first != package) {
        onExternal?.call(element);
        return;
      }
      if (element.isPrivate) {
        throw InvalidGenerationSourceError(
            'A class registered from module.dart must be public.',
            element: element);
      }
      path.add(element);
      final b = Binding(element, types, package);
      if (!RegExp(r'^[A-Za-z$][A-Za-z0-9_$]*$').hasMatch(b.name)) {
        throw InvalidGenerationSourceError(
            'Invalid public binding name "${b.name}".',
            element: element);
      }
      for (final symbol in [
        'Manage${b.name}',
        '${b.name}Params',
        '${b.name}Provider'
      ]) {
        final previous = symbols[symbol];
        if (previous != null) {
          throw InvalidGenerationSourceError(
              'Generated name $symbol is shared by '
              '${previous.library.source.uri} and ${element.library.source.uri}. '
              'Give one binding a distinct @ManagedType(name: ...).',
              element: element);
        }
        symbols[symbol] = element;
      }
      bindings.add(b);
      for (final input in b.inputs) {
        final child = input.dependency;
        if (child != null) visit(child);
      }
      path.removeLast();
    }

    for (final root in roots) {
      visit(root);
    }
    final body = StringBuffer();
    final emitter = DartEmitter();
    for (final binding in bindings) {
      for (final producer in [
        ExtendedManageProducer.forBinding(binding),
        ParamsProducer.forBinding(binding),
        ProviderProducer.forBinding(binding),
      ]) {
        body.writeln(producer.produce().accept(emitter));
      }
    }
    final out = StringBuffer(header);
    for (final import in types.imports.entries) {
      out.writeln('import ${dartString(import.key)} as ${import.value};');
    }
    if (bindings.any((b) => b.requiresParams)) out.writeln(_requiredParams);
    if (bindings.any((b) => b.inputs.any((p) => p.deferred)))
      out.writeln(_optionalArguments);
    out.write(body);
    return DartFormatter().format(out.toString());
  }
}

const _requiredParams = r'''
class _RequiredParams extends _m.Params {
  _RequiredParams(this.targetType, this.name);
  @_core.override final _core.Type targetType;
  final _core.String name;
  @_core.override void inject(_m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {
    throw _core.StateError('Provide $name when constructing $targetType.');
  }
}
''';

const _optionalArguments = r'''
class _Omitted { const _Omitted(); }
const _omitted = _Omitted();
T _invoke<T>(_core.Function constructor, _core.List<_core.Object?> positional,
    _core.Map<_core.Symbol, _core.Object?> named, _core.Map<_core.int, _core.Object?> defaults) {
  while (positional.isNotEmpty && _core.identical(positional.last, _omitted)) {
    positional.removeLast();
  }
  for (var i = 0; i < positional.length; i++) {
    if (!_core.identical(positional[i], _omitted)) continue;
    if (!defaults.containsKey(i)) {
      throw _core.ArgumentError('Supply preceding optional positional arguments when constructing $T.');
    }
    positional[i] = defaults[i];
  }
  return _core.Function.apply(constructor, positional, named) as T;
}
''';
