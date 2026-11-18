import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import '../binding.dart';
import '../dart_types.dart';
import '../generator.dart';

class ModuleBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': ['module.dart'],
      };

  @override
  Future<void> build(BuildStep step) async {
    final markers = await step.findAssets(Glob('lib/**.managed.json')).toList();
    markers.sort((a, b) => a.path.compareTo(b.path));
    final classes = <ClassElement>[];
    for (final marker in markers) {
      final source = AssetId(marker.package,
          marker.path.replaceFirst(RegExp(r'\.managed\.json$'), '.dart'));
      final library = await step.resolver.libraryFor(source);
      final names =
          (jsonDecode(await step.readAsString(marker)) as List).cast<String>();
      for (final name in names) {
        classes.add(library.getClass(name)!);
      }
    }
    final generator = ManagedGenerator(step.inputId.package);
    final external = <ClassElement>[];
    final code = generator.generate(classes, onExternal: external.add);
    final modules = <AssetId, LibraryElement>{};
    for (final type in external) {
      final owner = DartTypes.libraryUri(type.library).pathSegments.first;
      final id = AssetId(owner, 'lib/module.dart');
      final name = bindingName(type);
      if (await step.canRead(id)) {
        final module = modules[id] ??= await step.resolver.libraryFor(id);
        if (module.exportNamespace.get('${name}Provider') != null &&
            module.exportNamespace.get('${name}Params') != null) continue;
      }
      throw InvalidGenerationSourceError(
        'Missing ${name}Provider or ${name}Params in package:$owner/module.dart. '
        'Run build_runner in $owner and include lib/module.dart with the package.',
        element: type,
      );
    }
    await step.writeAsString(
        AssetId(step.inputId.package, 'lib/module.dart'), code);
  }
}
