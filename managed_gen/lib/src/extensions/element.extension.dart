import 'package:analyzer/dart/element/element.dart';
import 'package:managed/annotations.dart';
import 'package:source_gen/source_gen.dart';

extension ElementExt on Element {
  static final _checkerManagedType = TypeChecker.fromRuntime(ManagedType);

  ManagedType? get managedType {
    final annotations = _checkerManagedType.annotationsOf(this).iterator;
    if (!annotations.moveNext()) {
      return null;
    }
    final reader = ConstantReader(annotations.current);
    if (annotations.moveNext()) {
      throw InvalidGenerationSourceError(
          'Choose one @ManagedType registration per class.',
          element: this);
    }
    final enumIndex =
        reader.peek('scope')!.objectValue.getField('index')!.toIntValue()!;
    final scope = ScopeType.values[enumIndex];

    return ManagedType(
      scope: scope,
      constructor: reader.peek('constructor')?.stringValue,
      name: reader.peek('name')?.stringValue,
    );
  }

  bool get isManaged {
    return _checkerManagedType.hasAnnotationOf(this);
  }

  bool get hasUniqueScope => managedType?.scope == ScopeType.unique;
}

extension ClassElementExt on ClassElement {
  ConstructorElement get targetConstructor {
    final selection = managedType?.constructor;
    final selected = selection == 'new' ? '' : selection;
    final accessible = constructors
        .where((c) => c.isPublic && (!isAbstract || c.isFactory))
        .toList();
    final constructor =
        accessible.where((c) => c.name == (selected ?? '')).firstOrNull;
    if (constructor != null) return constructor;
    if (selected == null && accessible.length == 1) return accessible.single;
    throw InvalidGenerationSourceError(
      selected != null
          ? 'Cannot call constructor "$selected" of $displayName from module.dart.'
          : 'Choose a public constructor for $displayName using @ManagedType(constructor: ...). '
              'Available constructors: ${accessible.map((c) => c.displayName).join(', ')}.',
      element: this,
    );
  }
}
