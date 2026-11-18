import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:managed_gen/src/extensions/element.extension.dart';

class ManagedTypeCollector extends RecursiveElementVisitor<void> {
  final Set<Uri> managedTypes = {};

  @override
  void visitTypeAliasElement(TypeAliasElement element) {
    print('visitTypeAliasElement: $element');
    final referElement = element.aliasedElement;
    if (referElement is ClassElement) {
      if (referElement.isManaged) {
        final uri = referElement.library.source.uri.replace(
          fragment: referElement.name,
        );
        managedTypes.add(uri);
      }
      element.visitChildren(this);
    }
  }

  @override
  void visitSuperFormalParameterElement(SuperFormalParameterElement element) {
    print('visitSuperFormalParameterElement: $element');
    final type = element.type;
    final typeElement = type.element;
    if (type.isCoreType || typeElement == null) {
      return;
    }
    typeElement.visitChildren(this);
  }

  @override
  void visitPrefixElement(PrefixElement element) {
    print('visitPrefixElement: $element');
    element.visitChildren(this);
  }

  @override
  void visitLibraryImportElement(LibraryImportElement element) {
    print('visitLibraryImportElement: $element');
    element.visitChildren(this);
  }

  @override
  void visitLibraryElement(LibraryElement element) {
    print('visitLibraryElement: $element');
    element.visitChildren(this);
  }

  @override
  void visitLibraryAugmentationElement(LibraryAugmentationElement element) {
    print('visitLibraryAugmentationElement: $element');
    element.visitChildren(this);
  }

  @override
  void visitFieldFormalParameterElement(FieldFormalParameterElement element) {
    print(
        'visitFieldFormalParameterElement: $element src: ${element.source?.uri}');
    final type = element.type;
    final typeElement = type.element;
    if (type.isCoreType || typeElement == null) {
      return;
    }
    typeElement.visitChildren(this);
  }

  @override
  void visitConstructorElement(ConstructorElement element) {
    final classType = element.returnType.element;
    print('visitConstructorElement: $element for class $classType');
    if (classType is ClassElement) {
      if (classType.isManaged) {
        final uri =
            classType.library.source.uri.replace(fragment: classType.name);
        managedTypes.add(uri);
      }
    }

    element.visitChildren(this);
  }

  @override
  void visitCompilationUnitElement(CompilationUnitElement element) {
    print('visitCompilationUnitElement: $element');
    element.visitChildren(this);
  }

  @override
  void visitClassElement(ClassElement element) {
    print('visitClassElement: $element');
    if (element.isManaged) {
      final uri = element.library.source.uri.replace(fragment: element.name);
      managedTypes.add(uri);
    }
    element.visitChildren(this);
  }
}

extension DartTypeExt on DartType {
  bool get isCoreType {
    return isDartCoreType &&
        isDartAsyncFutureOr &&
        isDartAsyncFuture &&
        isDartAsyncStream &&
        isDartCoreBool &&
        isDartCoreDouble &&
        isDartCoreEnum &&
        isDartCoreFunction &&
        isDartCoreInt &&
        isDartCoreIterable &&
        isDartCoreList &&
        isDartCoreMap &&
        isDartCoreNull &&
        isDartCoreNum &&
        isDartCoreObject &&
        isDartCoreRecord &&
        isDartCoreSet &&
        isDartCoreString &&
        isDartCoreSymbol;
  }
}
