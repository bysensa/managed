import 'package:code_builder/code_builder.dart';

export 'producers/provider.producer.dart';

abstract class Producer {
  Spec produce();
}
