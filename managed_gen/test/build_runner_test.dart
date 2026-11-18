@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> packageRoot(String package, String library) async {
  final uri =
      await Isolate.resolvePackageUri(Uri.parse('package:$package/$library'));
  return File.fromUri(uri!).parent.parent;
}

void main() {
  late Directory work;
  late Directory client;
  late Directory catalog;
  late Directory generator;
  late Directory runtime;
  late Map<String, String> environment;
  File file(Directory dir, String relative) => File(p.join(dir.path, relative));

  Future<String> dart(Directory dir, List<String> args,
      {bool shouldFail = false}) async {
    final result = await Process.run(Platform.resolvedExecutable, args,
        workingDirectory: dir.path, environment: environment);
    final output = '${result.stdout}\n${result.stderr}';
    expect(result.exitCode, shouldFail ? isNonZero : 0,
        reason: 'dart ${args.join(' ')} in ${dir.path}\n$output');
    return output;
  }

  Future<String> build(Directory dir, {bool shouldFail = false}) =>
      dart(dir, ['run', 'build_runner', 'build'], shouldFail: shouldFail);

  Future<Directory> makePackage(String name, {Directory? catalog}) async {
    final package = Directory(p.join(work.path, name))..createSync();
    file(generator, 'analysis_options.yaml')
        .copySync(file(package, 'analysis_options.yaml').path);
    final fixtures =
        Directory(p.join(generator.path, 'test', 'fixtures', name));
    for (final input in fixtures.listSync(recursive: true).whereType<File>()) {
      final relative = p.relative(input.path, from: fixtures.path);
      final output = file(package, p.withoutExtension(relative));
      output.parent.createSync(recursive: true);
      input.copySync(output.path);
    }
    final deps = {
      'managed': {'path': runtime.path},
      if (catalog != null) 'catalog': {'path': catalog.path},
    };
    // JSON is a YAML subset and quotes paths portably.
    file(package, 'pubspec.yaml').writeAsStringSync(jsonEncode({
      'name': name,
      'publish_to': 'none',
      'environment': {'sdk': '^3.6.0'},
      'dependencies': deps,
      'dependency_overrides': {
        'managed': {'path': runtime.path}
      },
      'dev_dependencies': {
        'managed_gen': {'path': generator.path},
        'build_runner': '^2.4.9',
        'test': '^1.25.2',
      },
    }));
    await dart(package, ['pub', 'get', '--offline']);
    return package;
  }

  setUpAll(() async {
    generator = await packageRoot('managed_gen', 'build.dart');
    runtime = await packageRoot('managed', 'managed.dart');
    final scratch =
        Directory(p.join(generator.path, '.dart_tool', 'managed_gen_tests'))
          ..createSync(recursive: true);
    work = scratch.createTempSync('build_');
    final temp = Directory(p.join(work.path, 'tmp'))..createSync();
    environment = {
      'TMPDIR': temp.path,
      'TMP': temp.path,
      'TEMP': temp.path,
      'ANALYZER_STATE_LOCATION_OVERRIDE': p.join(work.path, 'analyzer'),
      'DART_SUPPRESS_ANALYTICS': 'true',
    };
    catalog = await makePackage('catalog');
    await build(catalog);
    client = await makePackage('client', catalog: catalog);
    file(generator, 'test/_files/simple.dart')
        .copySync(file(client, 'lib/original.dart').path);
    // models.dart is reachable through Pair. services_part.dart is part of its library.
    file(client, 'build.yaml').writeAsStringSync('''
targets:
  \$default:
    builders:
      managed_gen|managed_builder:
        generate_for: [lib/services.dart, lib/original.dart, lib/added.dart, lib/invalid.dart, lib/remote.dart, lib/nested/**]
''');
    await build(client);
  });

  tearDownAll(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  test('a fresh two-package build compiles and runs the binding contract',
      () async {
    await dart(client, ['analyze', 'lib/module.dart']);
    await dart(
        client, ['test', 'test/bindings_test.dart', '--reporter', 'expanded']);
  });

  test('the same generated module compiles to native code and JavaScript',
      () async {
    final executable =
        p.join('.dart_tool', Platform.isWindows ? 'smoke.exe' : 'smoke');
    await dart(client, ['compile', 'exe', 'bin/smoke.dart', '-o', executable]);
    final result = await Process.run(file(client, executable).path, [],
        workingDirectory: client.path, environment: environment);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    await dart(client, [
      'compile',
      'js',
      'bin/smoke.dart',
      '-O2',
      '-o',
      '.dart_tool/smoke.js'
    ]);
  });

  test(
      'incremental builds track edits, additions and deletions and reproduce clean output',
      () async {
    final module = file(client, 'lib/module.dart');
    final original = module.readAsStringSync();
    final part = file(client, 'lib/services_part.dart');
    final source = part.readAsStringSync();
    part.writeAsStringSync(source.replaceAll('17', '23'));
    await build(client);
    expect(module.readAsStringSync(), contains('this.amount = 23'));
    part.writeAsStringSync(source);
    final changing = file(client, 'lib/added.dart');
    changing.writeAsStringSync("""
      import 'package:managed/annotations.dart';
      @ManagedType(scope: ScopeType.unique)
      class Added {}
    """);
    await build(client);
    expect(module.readAsStringSync(), contains('AddedProvider'));
    changing.deleteSync();
    await build(client);
    expect(module.readAsStringSync(), original);
    await build(client);
    expect(module.readAsStringSync(), original);
    await dart(client, ['run', 'build_runner', 'clean']);
    // A clean removes the build cache but can leave source outputs in place.
    if (module.existsSync()) module.deleteSync();
    await build(client);
    expect(module.readAsStringSync(), original);
  });

  test('build_runner reports invalid annotations and recovers when fixed',
      () async {
    final changing = file(client, 'lib/invalid.dart');
    changing.writeAsStringSync("""
      import 'package:managed/annotations.dart';
      @ManagedType(scope: ScopeType.unique)
      enum Wrong { one }
    """);
    final diagnostic = await build(client, shouldFail: true);
    expect(diagnostic, contains('@ManagedType requires a class'));
    changing.writeAsStringSync("""
      import 'package:managed/annotations.dart';
      @ManagedType(scope: ScopeType.unique)
      class Fixed {}
    """);
    await build(client);
    expect(file(client, 'lib/module.dart').readAsStringSync(),
        contains('FixedProvider'));
  });

  test(
      'an outdated dependency module fails the build until the owner regenerates it',
      () async {
    file(catalog, 'lib/extra.dart').writeAsStringSync("""
      import 'package:managed/annotations.dart';
      @ManagedType(scope: ScopeType.singleton)
      class Remote {}
    """);
    file(client, 'lib/remote.dart').writeAsStringSync("""
      import 'package:catalog/extra.dart';
      import 'package:managed/annotations.dart';
      @ManagedType(scope: ScopeType.unique)
      class Local { Local(Remote remote); }
    """);
    expect(await build(client, shouldFail: true),
        contains('Missing RemoteProvider or RemoteParams'));
    await build(catalog);
    await build(client);
    await dart(client, ['analyze', 'lib/module.dart']);
  });
}
