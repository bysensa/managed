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

class _Account {
  _Account(this.id);
  final int id;
}

class _OptionalHolder {
  _OptionalHolder(this.account);
  final _Account? account;
}

void main() {
  tearDown(Scope.cached.reset);

  test('should not provide', () {
    expect(() => BadModule.root(), throwsStateError);
  });
  test('should provide', () {
    expect(GoodModule.root(), isA<Root>());
  });

  group('a lookup for a nullable parameter behaves as a non-nullable one', () {
    test('it receives the declared input instead of null', () {
      final account = Manage(() => _Account(1), scope: ScopeType.cached);
      // Inference picks the non-nullable type for the nullable parameter.
      final holder = Manage(() => _OptionalHolder(Manage.resolve()),
          dependsOn: [account]);
      expect(holder().account, same(account()));
    });

    test('it finds the input of an enclosing factory', () {
      final account = Manage(() => _Account(1), scope: ScopeType.cached);
      // dependsOn is optional: resolve<_Account>() would find this value.
      final inner = Manage(() => _OptionalHolder(Manage.resolve()));
      final outer = Manage(() => inner(), dependsOn: [account]);
      expect(outer().account, same(account()));
    });

    test('it fails loudly when the input is missing', () {
      final holder = Manage(() => _OptionalHolder(Manage.resolve()));
      expect(holder.call, throwsStateError);
    });
  });
}
