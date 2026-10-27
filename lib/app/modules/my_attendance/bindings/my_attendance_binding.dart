import 'package:get/get.dart';
import '../../../../core/services/self_attendance_repository.dart';
import '../controllers/attendance_correction_controller.dart';
import '../controllers/my_attendance_controller.dart';

void ensureSelfAttendanceRepository() {
  if (!Get.isRegistered<SelfAttendanceRepository>()) Get.lazyPut<SelfAttendanceRepository>(() => SelfAttendanceRepository(), fenix: true);
}

/// `/my-attendance`.
class MyAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    ensureSelfAttendanceRepository();
    Get.lazyPut<MyAttendanceController>(() => MyAttendanceController());
  }
}

/// `/my-attendance/correct`. The list controller (open behind) is updated on success.
class AttendanceCorrectionBinding extends Bindings {
  @override
  void dependencies() {
    ensureSelfAttendanceRepository();
    Get.lazyPut<AttendanceCorrectionController>(() => AttendanceCorrectionController());
  }
}
