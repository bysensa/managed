library annotations;

import 'package:meta/meta_meta.dart';

import 'managed.dart';

export 'managed.dart' show ScopeType;

@Target({TargetKind.classType})
class ManagedType {
  const ManagedType({required this.scope, this.constructor, this.name});

  final ScopeType scope;

  /// Selects a public named constructor when a class has several candidates.
  final String? constructor;

  /// Overrides the base name of the generated Params and provider.
  final String? name;

  @override
  String toString() {
    return 'ManagedType{scope: $scope}';
  }
}

class Module {
  const Module();
}
