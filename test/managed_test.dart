import 'package:flutter_test/flutter_test.dart';

import 'package:managed/managed.dart';

void main() {
  tearDown(() {
    ManagementContainer.reset();
  });

  test('should provide registered dependency', () {
    final dep =
        Dependency().availableAs<Dependency>().availableAs<DependencyApi>();

    expect(TestClass().instance(), isA<Dependency>());
    expect(TestClass().instance(), dep);

    expect(TestClass().instanceApi(), isA<DependencyApi>());
    expect(TestClass().instanceApi(), dep);
  });

  test('should check is registered', () {
    expect(ManagementContainer.isNotRegistered<Dependency>(), isTrue);
    expect(ManagementContainer.isNotRegistered<DependencyApi>(), isTrue);
    Dependency().availableAs<Dependency>().availableAs<DependencyApi>();
    expect(ManagementContainer.isRegistered<Dependency>(), isTrue);
    expect(ManagementContainer.isRegistered<DependencyApi>(), isTrue);
  });

  test('should throw on registration of unimplemented type', () {
    expect(
      () => Dependency().availableAs<UnimplementedApi>(),
      throwsStateError,
    );
  });

  test('should reset container', () {
    Dependency().availableAs<Dependency>().availableAs<DependencyApi>();
    expect(ManagementContainer.isRegistered<Dependency>(), isTrue);
    expect(ManagementContainer.isRegistered<DependencyApi>(), isTrue);
    ManagementContainer.reset();
    expect(ManagementContainer.isNotRegistered<Dependency>(), isTrue);
    expect(ManagementContainer.isNotRegistered<DependencyApi>(), isTrue);
  });
}

class TestClass with Managed {
  T instance<T extends Dependency>();
  T instanceApi<T extends DependencyApi>();
}

mixin DependencyApi {}

mixin UnimplementedApi {}

class Dependency with Manageable, DependencyApi {}
