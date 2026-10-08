import 'package:get/get.dart';
import '../../../../core/services/leave_repository.dart';
import '../controllers/leave_apply_controller.dart';
import '../controllers/leave_controller.dart';

void ensureLeaveRepository() {
  if (!Get.isRegistered<LeaveRepository>()) Get.lazyPut<LeaveRepository>(() => LeaveRepository(), fenix: true);
}

/// `/leave`.
class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    ensureLeaveRepository();
    Get.lazyPut<LeaveController>(() => LeaveController());
  }
}

/// `/leave/apply`. The list controller (when the list is open behind) is reused for hints and updated on success.
class LeaveApplyBinding extends Bindings {
  @override
  void dependencies() {
    ensureLeaveRepository();
    Get.lazyPut<LeaveApplyController>(() => LeaveApplyController());
  }
}
