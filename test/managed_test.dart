import 'package:flutter_test/flutter_test.dart';

import 'package:managed/managed.dart';

void main() {
  test('should provide dependency', () {
    Dependency testFactory() => Dependency();
    Manage(testFactory);
    final testClass = TestClass();
    expect(testClass.dependency(), isA<Dependency>());
  });

  test('should provide same dependency on multiple calls', () {
    Dependency testFactory() => Dependency();
    Manage(testFactory, scope: Scope.unique);
    final testClass = TestClass();
    final dependency1 = testClass.dependency();
    final dependency2 = testClass.dependency();
    expect(dependency1, dependency2);
  });
}

class Dependency {}

class TestClass with Managed {
  T dependency<T extends Dependency>();
}
