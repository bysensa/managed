import 'package:flutter_test/flutter_test.dart';
import 'package:managed/managed.dart';

void main() {
  setUpAll(() {
    TestModule();
  });

  test('should provide same instance from different mixins', () {
    final testClass = TestClass();
    final instanceFromFirst = testClass.serviceFromFirst();
    final instanceFromSecond = testClass.serviceFromSecond();
    expect(instanceFromFirst, isA<TestService>());
    expect(instanceFromSecond, isA<TestService>());
    expect(instanceFromFirst, instanceFromSecond);
  });
}

class TestModule extends Module {
  TestModule() : super({service});

  static final service = Manage(TestService.new);
}

class TestService {}

class TestClass with Managed, FirstMixin, SecondMixin {}

mixin FirstMixin {
  T serviceFromFirst<T extends TestService>();
}

mixin SecondMixin {
  T serviceFromSecond<T extends TestService>();
}
