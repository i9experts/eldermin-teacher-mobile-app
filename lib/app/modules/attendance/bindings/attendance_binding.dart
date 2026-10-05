import 'package:get/get.dart';
import '../../../../core/services/attendance_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/attendance_history_controller.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
    if (!Get.isRegistered<AttendanceRepository>()) Get.lazyPut<AttendanceRepository>(() => AttendanceRepository(), fenix: true);
    Get.lazyPut<AttendanceController>(() => AttendanceController(), fenix: true);
    Get.lazyPut<AttendanceHistoryController>(() => AttendanceHistoryController(), fenix: true);
  }
}
