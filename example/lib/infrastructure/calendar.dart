import 'package:device_calendar/device_calendar.dart';
import 'package:lumberdash/lumberdash.dart';

mixin CalendarApi {
  Future<bool> hasAccess();
  Future<bool> requestPermissions();
}

class CalendarService with CalendarApi {
  final _deviceCalendar = DeviceCalendarPlugin();

  @override
  Future<bool> hasAccess() async {
    final res = await _deviceCalendar.hasPermissions();
    if (res.isSuccess) {
      return res.data!;
    }
    res.errors.forEach(logError);
    return false;
  }

  @override
  Future<bool> requestPermissions() async {
    final res = await _deviceCalendar.requestPermissions();
    if (res.isSuccess) {
      return res.data!;
    }
    res.errors
        .map((e) => '${e.errorCode}: ${e.errorMessage}')
        .forEach(logError);
    return false;
  }
}
