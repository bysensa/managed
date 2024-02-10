import 'package:managed/managed.dart';
import 'package:test/test.dart';

class Dependency {}

class Root {
  final Dependency dep;

  Root({
    Dependency? dep,
  }) : dep = dep ?? Manage.resolve();

  factory Root.managed() {
    return Root(dep: Manage.resolve());
  }
}

abstract class BadModule {
  static final dependency = Manage(Dependency.new);
  static final root = Manage(Root.new);
}

abstract class GoodModule {
  static final dependency = Manage(Dependency.new);
  static final root = Manage(
    Root.managed,
    dependsOn: [dependency],
  );
}

void main() {
  test('should not provide', () {
    expect(() => BadModule.root(), throwsStateError);
  });
  test('should provide', () {
    expect(GoodModule.root(), isA<Root>());
  });
}
