import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:managed/annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Marks the libraries selected by generate_for. ModuleBuilder resolves these
/// libraries together so references, names and imports agree across files.
class ManagedBuilder implements Builder {
  ManagedBuilder({BuilderOptions? options});

  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.managed.json'],
      };

  @override
  Future<void> build(BuildStep step) async {
    if (!await step.resolver.isLibrary(step.inputId)) return;
    final library = LibraryReader(await step.inputLibrary);
    final checker = TypeChecker.fromRuntime(ManagedType);
    final names = <String>[];
    for (final annotated in library.annotatedWith(checker)) {
      if (annotated.element is! ClassElement) {
        throw InvalidGenerationSourceError('@ManagedType requires a class.',
            element: annotated.element);
      }
      names.add(annotated.element.displayName);
    }
    if (names.isNotEmpty) {
      await step.writeAsString(step.inputId.changeExtension('.managed.json'),
          jsonEncode(names..sort()));
    }
  }
}
