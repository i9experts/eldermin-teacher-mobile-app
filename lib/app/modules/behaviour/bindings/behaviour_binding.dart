import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/behaviour_controller.dart';
import '../controllers/behaviour_log_controller.dart';
import '../controllers/behaviour_student_controller.dart';

void _shared() {
  if (!Get.isRegistered<BehaviourRepository>()) Get.lazyPut<BehaviourRepository>(() => BehaviourRepository(), fenix: true);
  if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
  Get.lazyPut<BehaviourController>(() => BehaviourController(), fenix: true);
}

/// `/behaviour`.
class BehaviourBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/behaviour/new` (optionally with a [StudentSummary] in `arguments` to preselect the student).
class BehaviourLogBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<BehaviourLogController>(() => BehaviourLogController(initialStudent: arg is StudentSummary ? arg : null));
  }
}

/// `/behaviour/student/:id` (a [StudentSummary] in `arguments` skips the roster lookup).
class BehaviourStudentBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<BehaviourStudentController>(
        () => BehaviourStudentController(studentId: Get.parameters['id'] ?? '', initial: arg is StudentSummary ? arg : null));
  }
}
