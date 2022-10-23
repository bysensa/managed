import 'package:flutter_test/flutter_test.dart';
import 'package:managed/managed.dart';

void main() {
  setUpAll(() {
    TestModule();
  });

  test('should provide correct dependency once', () {
    final testClass = TestClass();
    final providedInstance = testClass.instance();
    expect(providedInstance, isA<TestService>());
    expect(testClass.instance(), providedInstance);
  });
}

class TestModule extends Module {
  static final service = Manage(TestService.new);

  TestModule() : super({service});
}

class TestService {}

abstract class Base<T extends Object> with Managed {
  S instance<S extends T>();
}

class TestClass extends Base<TestService> {}
