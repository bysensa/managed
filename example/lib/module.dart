import 'package:example/infrastructure/calendar.dart';
import 'package:managed/managed.dart';

class AppModule {
  static final calendarApi = Manage<CalendarApi>(CalendarService.new);
}
