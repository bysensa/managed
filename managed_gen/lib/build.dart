import 'package:build/build.dart';

import 'src/builders.dart';

Builder generateManaged(BuilderOptions options) {
  return ManagedBuilder(options: options);
}

Builder generateModule(BuilderOptions options) {
  return ModuleBuilder();
}
