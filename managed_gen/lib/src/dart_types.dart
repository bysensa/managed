import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

String dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

/// Type names are rendered with their defining library, including names inside
/// generics, records, function signatures, bounds and typedefs.
class DartTypes {
  final _typeNames = <TypeParameterElement, String>{};
  /// Generated code reaches the runtime, including its Params support, here.
  static const _runtime = 'package:managed/codegen.dart';

  final imports = <String, String>{
    'dart:core': '_core',
    'dart:async': '_async',
    _runtime: '_m',
  };

  static Uri libraryUri(LibraryElement library) {
    final uri = library.source.uri;
    if (uri.scheme == 'asset' &&
        uri.pathSegments.length > 2 &&
        uri.pathSegments[1] == 'lib') {
      return Uri.parse(
          'package:${uri.pathSegments.first}/${uri.pathSegments.skip(2).join('/')}');
    }
    return uri;
  }

  String prefix(String uri) =>
      imports.putIfAbsent(uri, () => '_i${imports.length - 2}');

  String symbol(Element element) {
    if (element.isPrivate) {
      throw InvalidGenerationSourceError(
          'The type ${element.displayName} is private to its library. '
          'Expose a public type or typedef for the generated API.',
          element: element);
    }
    final uri = libraryUri(element.library!).toString();
    // The runtime is implemented under src/ and exported by codegen.dart.
    final library = uri.startsWith('package:managed/src/') ? _runtime : uri;
    return '${prefix(library)}.${element.displayName}';
  }

  String arguments(Iterable<DartType> types) =>
      types.isEmpty ? '' : '<${types.map(render).join(', ')}>';

  // A user's type variable can have the same name as a generated class.
  String _typeName(TypeParameterElement element) =>
      _typeNames.putIfAbsent(element, () => '_T${_typeNames.length}');

  String formals(List<TypeParameterElement> parameters) {
    if (parameters.isEmpty) return '';
    return '<${parameters.map((p) {
      final bound = p.bound;
      final name = _typeName(p);
      return bound == null ? name : '$name extends ${render(bound)}';
    }).join(', ')}>';
  }

  String render(DartType type) {
    final suffix =
        type.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
    final alias = type.alias;
    if (alias != null && alias.element.isPublic) {
      return '${symbol(alias.element)}${arguments(alias.typeArguments)}$suffix';
    }
    if (type is InterfaceType) {
      return '${symbol(type.element)}${arguments(type.typeArguments)}$suffix';
    }
    if (type is TypeParameterType) return '${_typeName(type.element)}$suffix';
    if (type is DynamicType) return 'dynamic';
    if (type is VoidType) return 'void';
    if (type is NeverType) return '_core.Never$suffix';
    if (type is RecordType) {
      final fields = type.positionalFields.map((f) => render(f.type)).toList();
      if (type.namedFields.isNotEmpty) {
        fields.add(
            '{${type.namedFields.map((f) => '${render(f.type)} ${f.name}').join(', ')}}');
      }
      final comma = fields.length == 1 && type.namedFields.isEmpty ? ',' : '';
      return '(${fields.join(', ')}$comma)$suffix';
    }
    if (type is FunctionType) {
      final parameters = type.parameters;
      final fields = parameters
          .where((p) => p.isRequiredPositional)
          .map((p) => render(p.type))
          .toList();
      final optional = parameters.where((p) => p.isOptionalPositional);
      final named = parameters.where((p) => p.isNamed);
      if (optional.isNotEmpty)
        fields.add('[${optional.map((p) => render(p.type)).join(', ')}]');
      if (named.isNotEmpty) {
        fields.add(
            '{${named.map((p) => '${p.isRequiredNamed ? 'required ' : ''}${render(p.type)} ${p.name}').join(', ')}}');
      }
      return '${render(type.returnType)} Function${formals(type.typeFormals)}(${fields.join(', ')})$suffix';
    }
    throw InvalidGenerationSourceError(
        'Cannot name parameter type "$type" in the generated module.');
  }
}
