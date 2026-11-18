library annotations;

import 'managed.dart';

export 'managed.dart' show ScopeType;

class ManagedType {
  const ManagedType({required this.scope});

  final ScopeType scope;

  @override
  String toString() {
    return 'ManagedType{scope: $scope}';
  }
}

class Module {
  const Module();
}
