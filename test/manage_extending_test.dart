import 'dart:async';

import 'package:managed/annotations.dart';
import 'package:managed/managed.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

@ManagedType(scope: ScopeType.cached)
class Empty {
  Empty(this.text);

  final String text;

  @override
  String toString() {
    return 'Empty{text: $text}';
  }
}

class EmptyParams extends Params {
  EmptyParams({
    required this.text,
  });

  final String text;

  @override
  void inject(ZoneValues values, Map<Type, Manage> dependencies) {
    values[#text] = text;
  }

  @override
  Type get targetType => Empty;
}

class ManageEmpty = Manage<Empty> with EmptyProvider;

mixin EmptyProvider on Manage<Empty> {
  static Empty managed() {
    return Empty(Zone.current[#text]);
  }

  @override
  Empty call([covariant EmptyParams? params]) {
    final ZoneValues values = {};
    final deps = {for (final dep in dependencies) dep.managedType: dep};
    params?.inject(values, deps);
    return runZoned(() {
      return callForGenerated();
    }, zoneValues: values);
  }
}

class Middle {
  Middle(this.empty);

  final Empty empty;

  @override
  String toString() {
    return 'Middle{empty: $empty}';
  }
}

class MiddleParams extends Params {
  MiddleParams({
    required this.empty,
  });

  final EmptyParams empty;

  @override
  void inject(ZoneValues values, Map<Type, Manage> dependencies) {
    values[#empty] = empty;
    values[empty.targetType] = dependencies[empty.targetType]?.call(empty);
  }

  @override
  Type get targetType => Middle;
}

class ManageMiddle = Manage<Middle> with MiddleProvider;

mixin MiddleProvider on Manage<Middle> {
  static Middle managed() {
    return Middle(Manage.resolve());
  }

  @override
  Middle call([covariant MiddleParams? params]) {
    final ZoneValues values = {};
    final deps = {for (final dep in dependencies) dep.managedType: dep};
    params?.inject(values, deps);
    return runZoned(() {
      return callForGenerated();
    }, zoneValues: values);
  }
}

class Some {
  Some({
    required this.number,
    required this.flag,
    required this.middle,
  });

  final int number;
  final bool flag;
  final Middle middle;

  @override
  String toString() {
    return 'Some{number: $number, flag: $flag, middle: $middle}';
  }
}

class SomeParams extends Params {
  SomeParams({
    required this.number,
    required this.flag,
    required this.middle,
  });

  final int number;
  final bool flag;
  final MiddleParams middle;

  @override
  void inject(ZoneValues values, Map<Type, Manage> dependencies) {
    values[#number] = number;
    values[#flag] = flag;
    values[#middle] = middle;
    values[middle.targetType] = dependencies[middle.targetType]?.call(middle);
  }

  @override
  Type get targetType => Some;
}

class ManageSome = Manage<Some> with SomeProvider;

mixin SomeProvider on Manage<Some> {
  static Some managed() {
    final zone = Zone.current;
    return Some(
      number: zone[#number],
      flag: zone[#flag],
      middle: Manage.resolve(),
    );
  }

  @override
  Some call([covariant SomeParams? params]) {
    final ZoneValues values = {};
    final deps = {for (final dep in dependencies) dep.managedType: dep};
    params?.inject(values, deps);
    return runZoned(() {
      return callForGenerated();
    }, zoneValues: values);
  }
}

abstract class Module {
  static final empty = ManageEmpty(
    EmptyProvider.managed,
    scope: ScopeType.unique,
  );
  static final middle = ManageMiddle(
    MiddleProvider.managed,
    scope: ScopeType.unique,
    dependsOn: [empty],
  );
  static final some = ManageSome(
    SomeProvider.managed,
    scope: ScopeType.unique,
    dependsOn: [middle],
  );
}

void main() {
  test('should provide', () {
    final params = SomeParams(
      number: 1,
      flag: true,
      middle: MiddleParams(
        empty: EmptyParams(
          text: 'HelloWorld',
        ),
      ),
    );
    final instance = Module.some(params);
    print(instance);
  });

  test('should provide', () {
    final params = MiddleParams(
      empty: EmptyParams(
        text: 'HelloWorld',
      ),
    );
    final instance = Module.middle(params);
    print(instance);
  });

  test('should provide', () {
    final params = EmptyParams(text: 'HelloWorld');
    final instance = Module.empty(params);
    print(instance);
  });
}
