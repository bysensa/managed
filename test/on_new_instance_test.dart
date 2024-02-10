import 'package:managed/annotations.dart';
import 'package:managed/managed.dart';
import 'package:test/test.dart';

class Test {}

void main() {
  test('should invoke onNewInstance with unique scope', () {
    int invocationCount = 0;
    final manage = Manage(
      Test.new,
      onNewInstance: (i) => invocationCount += 1,
      scope: ScopeType.unique,
    );
    manage();
    expect(invocationCount, 1);
    manage();
    expect(invocationCount, 2);
    Scope.unique.reset();
    manage();
    expect(invocationCount, 3);
  });

  test('should invoke onNewInstance with cached scope', () {
    int invocationCount = 0;
    final manage = Manage(
      Test.new,
      onNewInstance: (i) => invocationCount += 1,
      scope: ScopeType.cached,
    );
    manage();
    expect(invocationCount, 1);
    manage();
    expect(invocationCount, 1);
    Scope.cached.reset();
    manage();
    expect(invocationCount, 2);
  });

  test('should invoke onNewInstance with singleton scope', () {
    int invocationCount = 0;
    final manage = Manage(
      Test.new,
      onNewInstance: (i) => invocationCount += 1,
      scope: ScopeType.singleton,
    );
    manage();
    expect(invocationCount, 1);
    manage();
    expect(invocationCount, 1);
    Scope.singleton.reset();
    manage();
    expect(invocationCount, 1);
  });
}
