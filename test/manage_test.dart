import 'package:flutter_test/flutter_test.dart';
import 'package:managed/managed.dart';

class TestClass {}

void main() {
  tearDown(() {
    Manage.resetTypeInstance(TestClass);
  });

  test('should register instance globally', () {
    expect(Manage.manageInstance(TestClass), isNull);
    final manage = Manage(TestClass.new);
    expect(Manage.manageInstance(TestClass), manage);
  });

  test('can add mock', () {
    final mock = TestClass();
    final manage = Manage(TestClass.new);
    manage.mock(mock);
    expect(manage.call(), mock);
  });

  test('can reset mock', () {
    final mock = TestClass();
    final manage = Manage(TestClass.new);
    manage.mock(mock);
    expect(manage.call(), mock);
    expect(manage.call(), mock);
    manage.resetMock();
    expect(manage.call(), isNot(mock));
    expect(manage.call(), isNot(mock));
  });
}
