import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:managed_gen/src/generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  const sources = {
    'ambiguous constructors': (
      'class Root { Root.one(); Root.two(); }',
      'Choose a public constructor for Root',
    ),
    'inaccessible constructor': (
      'class Root { Root._(); }',
      'Choose a public constructor for Root',
    ),
    'explicit missing constructor': (
      "class Root { Root(); }",
      'Cannot call constructor "missing" of Root',
    ),
    'abstract class without a factory': (
      'abstract class Root {}',
      'Choose a public constructor for Root',
    ),
    'private managed class': (
      'class _Root {}',
      'must be public',
    ),
    'private argument type': (
      'class Root { Root(_Hidden input); } class _Hidden {}',
      'type _Hidden is private',
    ),
    'invalid binding name': (
      'class Root {}',
      'Invalid public binding name',
    ),
    'multiple annotations on one class': (
      '@binding class Root {}',
      'Choose one @ManagedType',
    ),
    'direct dependency cycle': (
      'class Root { Root(Root parent); }',
      'Root -> Root',
    ),
    'transitive dependency cycle': (
      'class Root { Root(Next next); } @binding class Next { Next(Root root); }',
      'Root -> Next -> Root',
    ),
    'duplicate generated name': (
      "class Root {} @ManagedType(scope: ScopeType.cached, name: 'Root') class Other {}",
      'Generated name ManageRoot is shared',
    ),
  };

  for (final entry in sources.entries) {
    test('diagnoses ${entry.key}', () async {
      final option = switch (entry.key) {
        'explicit missing constructor' => ", constructor: 'missing'",
        'invalid binding name' => ", name: 'not-a-name'",
        _ => '',
      };
      final id = AssetId('managed_gen', 'lib/invalid.dart');
      final source = """
        import 'package:managed/annotations.dart';
        const binding = ManagedType(scope: ScopeType.unique$option);
        @binding ${entry.value.$1}
      """;
      await expectLater(
        resolveSources({id.toString(): source}, (resolver) async {
          final library = await resolver.libraryFor(id);
          final roots = library.units
              .expand((unit) => unit.classes)
              .where((element) => element.metadata.isNotEmpty);
          return ManagedGenerator(id.package).generate(roots);
        }, resolverFor: id.toString()),
        throwsA(isA<InvalidGenerationSourceError>().having(
          (error) => error.message,
          'diagnostic',
          contains(entry.value.$2),
        )),
      );
    });
  }
}
