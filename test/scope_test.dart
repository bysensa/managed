import 'package:flutter_test/flutter_test.dart';
import 'package:managed/managed.dart';

void main() {
  group('unique scope tests', () {
    test('should reset', () {
      Scope.unique.reset();
    });

    test('should create new instance every time', () {
      final instance1 = Scope.unique.provideUsing(TestClass.new);
      final instance2 = Scope.unique.provideUsing(TestClass.new);
      expect(instance1, isNot(instance2));
    });
  });

  group('cached scope tests', () {
    test('should create new instance only once', () {
      TestClass testFactory() => TestClass();
      var instance1 = Scope.cached.provideUsing(testFactory);
      var instance2 = Scope.cached.provideUsing(testFactory);
      expect(instance1, instance2);
    });

    test('should reset', () {
      TestClass testFactory() => TestClass();
      var instance1 = Scope.cached.provideUsing(testFactory);
      var instance2 = Scope.cached.provideUsing(testFactory);
      expect(instance1, instance2);
      Scope.cached.reset();
      var instance3 = Scope.cached.provideUsing(testFactory);
      expect(instance2, isNot(instance3));
    });
  });

  group('singleton scope tests', () {
    test('should create new instance only once', () {
      TestClass testFactory() => TestClass();
      var instance1 = Scope.singleton.provideUsing(testFactory);
      var instance2 = Scope.singleton.provideUsing(testFactory);
      expect(instance1, instance2);
    });

    test('should reset', () {
      TestClass testFactory() => TestClass();
      var instance1 = Scope.singleton.provideUsing(testFactory);
      var instance2 = Scope.singleton.provideUsing(testFactory);
      expect(instance1, instance2);
      Scope.singleton.reset();
      var instance3 = Scope.singleton.provideUsing(testFactory);
      expect(instance2, instance3);
    });
  });
}

class TestClass {}
