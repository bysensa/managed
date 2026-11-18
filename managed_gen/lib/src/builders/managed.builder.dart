import 'package:source_gen/source_gen.dart';

import '../generator.dart';

class ManagedBuilder extends LibraryBuilder {
  ManagedBuilder({super.options})
      : super(
          ManagedGenerator(),
          generatedExtension: '.managed.dart',
          header: '',
          formatOutput: (content) => content,
        );
}
