import 'package:isar/isar.dart';

part 'project.g.dart';

@collection
class Project {
  Id id = Isar.autoIncrement; // you can also use id = null to auto increment

  @Index(type: IndexType.value)
  String title = '';

  String? description;
}
