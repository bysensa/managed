library example;

import 'package:managed/annotations.dart';

@ManagedType(scope: ScopeType.singleton)
class Singleton {}

@ManagedType(scope: ScopeType.cached)
class Cached {}

@ManagedType(scope: ScopeType.unique)
class Unique {}

@ManagedType(scope: ScopeType.unique)
class Boo extends Hello with My, Friends implements World {
  Boo(
    this.unique, {
    this.flag,
    this.cached,
    required this.single,
  });

  final Singleton single;
  final Cached? cached;
  final Unique? unique;
  final bool? flag;
}

abstract class Hello {}

abstract class World {}

mixin My {}

mixin class Friends {}
