import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:managed/annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../binding.dart';
import '../dart_types.dart';
import '../extensions/element.extension.dart';
import '../producers.dart';

class ProviderProducer extends Producer {
  ProviderProducer({required ClassElement managedType})
      : this.forBinding(Binding.forElement(managedType));
  ProviderProducer.forBinding(this.binding);
  final Binding binding;
  ClassElement get managedType => binding.element;
  static final checkerManagedType = TypeChecker.fromRuntime(ManagedType);
  ConstructorElement get constructor => binding.constructor;
  ManagedType get meta => managedType.managedType!;
  List<ParameterElement> get parameters => constructor.parameters;
  List<ParameterElement> get managedParameters =>
      parameters.where((p) => managedInput(p) != null).toList();
  DartObject? get annotationManagedType =>
      checkerManagedType.firstAnnotationOf(managedType);

  @override
  Spec produce() {
    final b = binding;
    final provider = '${b.name}Provider';
    final registration = 'Manage${b.name}${b.arguments}';
    final params = '${b.name}Params${b.arguments}';
    final dependencies = {
      for (final p in b.inputs)
        if (p.dependency != null) p.provider
    };
    // An explicit registration of the same type replaces the inferred edge
    // for both resolution and lifecycle tracking.
    final inputs = dependencies.isEmpty
        ? 'dependsOn'
        : '''
      [for (final dep in <_m.Manage>[${dependencies.join(', ')}])
        if (!dependsOn.any((d) => d.managedType == dep.managedType)) dep,
        ...dependsOn]
    ''';
    final out = StringBuffer()
      ..writeln('mixin $provider${b.formals} on _m.Manage<${b.target}> {');
    if (b.generic) {
      out.writeln('static final _providers = <_core.Type, _m.Manage>{};');
      out.writeln(
          'static $registration of${b.formals}() => _providers.putIfAbsent('
          '${b.target}, () => register${b.arguments}()) as $registration;');
    } else {
      out.writeln('static final $registration provider = register();');
    }
    final shared = b.scope != ScopeType.unique;
    if (shared && !b.generic) out.writeln('static $params? params;');
    final defaults = shared && b.generic ? 'params' : '_defaults';
    out.writeln('$params? $defaults;');
    out.writeln('static $registration register${b.formals}({$params? params, '
        '_core.List<_m.Manage> dependsOn = const [], _m.OnNewInstance<${b.target}>? onNewInstance, '
        '_m.OnDispose<${b.target}>? onDispose}) => $registration(_managed${b.arguments}, '
        'scope: _m.ScopeType.${b.scope.name}, '
        'dependsOn: $inputs, '
        'onNewInstance: onNewInstance, onDispose: onDispose)..$defaults = params;');
    out.writeln('static ${b.target} _managed${b.formals}() => '
        '(_async.Zone.current[$params] as ${b.target} Function())();');
    final fallback = b.requiresParams
        ? '_RequiredParams(${b.target}, ${dartString(b.name + 'Params')})'
        : '$params()';
    final configured = shared && !b.generic
        ? '_defaults ?? $provider.params'
        : 'this.$defaults';
    out.writeln(
        '@_core.override ${b.target} call([covariant $params? params]) => '
        'super.call(params ?? $configured ?? $fallback);');
    out.writeln('}');
    return Code(out.toString());
  }
}
