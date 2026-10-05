import 'package:get/get.dart';
import '../../attendance/bindings/attendance_binding.dart';
import '../../classes/bindings/classes_binding.dart';
import '../../messages/bindings/messages_binding.dart';
import '../../more/bindings/more_binding.dart';
import '../../timetable/bindings/timetable_binding.dart';
import '../controllers/home_dashboard_controller.dart';
import '../controllers/home_shell_controller.dart';

/// Registers the shell and every tab's controller (the tabs live in one
/// IndexedStack, so they are all needed up front).
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeShellController>(() => HomeShellController(), fenix: true);
    Get.lazyPut<HomeDashboardController>(() => HomeDashboardController(), fenix: true);
    ClassesBinding().dependencies();
    AttendanceBinding().dependencies();
    TimetableBinding().dependencies();
    MessagesBinding().dependencies();
    MoreBinding().dependencies();
  }
}
