import 'package:get/get.dart';
import '../../../../core/services/school_calendar_repository.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/circulars_controller.dart';

void ensureSchoolCalendarRepository() {
  if (!Get.isRegistered<SchoolCalendarRepository>()) Get.lazyPut<SchoolCalendarRepository>(() => SchoolCalendarRepository(), fenix: true);
}

/// `/calendar` (Calendar tab + Circulars tab).
class CalendarBinding extends Bindings {
  @override
  void dependencies() {
    ensureSchoolCalendarRepository();
    Get.lazyPut<CalendarController>(() => CalendarController());
    Get.lazyPut<CircularsController>(() => CircularsController());
  }
}
