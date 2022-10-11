import 'package:example/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import 'database/project.dart';

typedef Database = Isar;

class DatabaseProvider {
  final _db = Async(
    () => Isar.open(
      [ProjectSchema],
      inspector: kDebugMode,
    ),
  );

  Future<AsyncResult<Database>> get instance => _db.instance;
}
