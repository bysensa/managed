import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

class ModuleBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      r'$lib$': ['module.dart']
    };
  }

  static AssetId _allFileOutput(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      p.join('lib', 'module.dart'),
    );
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final imports = <String>{};
    final content = <String>[];

    imports.add("import 'dart:async';");
    imports.add("import 'package:managed/managed.dart';");

    await for (final input
        in buildStep.findAssets(Glob('lib/**.managed.dart'))) {
      // final library = await buildStep.resolver.libraryFor(input);
      // final classesInLibrary = LibraryReader(library).classes;
      //
      // classNames.addAll(classesInLibrary.map((c) => c.name));
      final fileContent = await buildStep.readAsString(input);
      fileContent.split('\n').forEach((element) {
        final isImport = element.startsWith('import');
        isImport ? imports.add(element) : content.add(element);
      });
    }

    final outputBuffer = StringBuffer();
    outputBuffer.writeAll(imports, '\n');
    outputBuffer.writeAll(content, '\n');

    await buildStep.writeAsString(
      _allFileOutput(buildStep),
      outputBuffer.toString(),
    );
  }
}
