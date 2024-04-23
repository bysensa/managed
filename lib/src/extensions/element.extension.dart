import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:managed/annotations.dart';
import 'package:managed_gen/src/model/managed_type_meta.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

extension ElementExt on Element {
  static final _checkerManagedType = TypeChecker.fromRuntime(ManagedType);

  ManagedType? get managedType {
    final annotation = _checkerManagedType.firstAnnotationOfExact(this);
    if (annotation == null) {
      return null;
    }
    final reader = ConstantReader(annotation);
    final enumIndex = reader.peek('scope')!.objectValue.getField('index')!.toIntValue()!;
    final scope = ScopeType.values[enumIndex];

    return ManagedType(scope: scope);
  }

  bool get isManaged {
    return _checkerManagedType.hasAnnotationOfExact(this);
  }

  bool get isNotManaged => !isManaged;

  bool get hasNotUniqueScope => !hasUniqueScope;

  bool get hasUniqueScope => managedType?.scope == ScopeType.unique;

  bool get hasNotCachedScope => !hasCachedScope;

  bool get hasCachedScope => managedType?.scope == ScopeType.cached;

  bool get hasNotSingletonScope => !hasSingletonScope;

  bool get hasSingletonScope => managedType?.scope == ScopeType.singleton;
}

extension ClassElementExt on ClassElement {
  ConstructorElement get targetConstructor {
    final constructor =
        constructors.where((constructor) => constructor.name.isEmpty).firstOrNull;
    if (constructor == null) {
      throw Exception(
          'Class annotated with ManagedType must provide constructor without name');
    }
    return constructor;
  }

  String get nameInCamelCase => name.camelCase;

  String get providerMixinName => '${displayName}Provider';

  String get paramsClassName => '${displayName}Params';

  String get extendedManageClassName => 'Manage${displayName}';

  String get manageForClassTypeName => 'Manage<${displayName}>';
}

extension ConstructorElementExt on ConstructorElement {
  ClassElement get relatedClass => returnType.element as ClassElement;

  String get nameInCamelCase => relatedClass.nameInCamelCase;

  String get providerMixinName => relatedClass.providerMixinName;

  String get paramsClassName => relatedClass.paramsClassName;

  String get extendedManageClassName => relatedClass.extendedManageClassName;

  String get manageForClassTypeName => relatedClass.manageForClassTypeName;
}

extension ParameterElementExt on ParameterElement {
  Element? get typeElement => type.element;

  bool get isManaged => typeElement?.isManaged ?? false;

  bool get hasNotUniqueScope => !hasUniqueScope;

  bool get hasUniqueScope => typeElement?.managedType?.scope == ScopeType.unique;

  bool get hasNotCachedScope => !hasCachedScope;

  bool get hasCachedScope => typeElement?.managedType?.scope == ScopeType.cached;

  bool get hasNotSingletonScope => !hasSingletonScope;

  bool get hasSingletonScope => typeElement?.managedType?.scope == ScopeType.singleton;
}
