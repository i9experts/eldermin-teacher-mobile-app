import 'package:get/get.dart';
import '../../../../core/services/homework_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../controllers/homework_controller.dart';
import '../controllers/homework_detail_controller.dart';
import '../controllers/homework_form_controller.dart';
import '../controllers/submissions_controller.dart';

void _shared() {
  if (!Get.isRegistered<HomeworkRepository>()) Get.lazyPut<HomeworkRepository>(() => HomeworkRepository(), fenix: true);
  if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
  Get.lazyPut<HomeworkController>(() => HomeworkController(), fenix: true);
}

/// `/homework`: the list.
class HomeworkBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/homework/new`: create, or edit when the route carries an [Assignment] in `arguments`.
class HomeworkFormBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<HomeworkFormController>(() => HomeworkFormController(editing: arg is Assignment ? arg : null));
  }
}

/// `/homework/:id`.
class HomeworkDetailBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<HomeworkDetailController>(() => HomeworkDetailController(id: Get.parameters['id'] ?? ''));
  }
}

/// `/homework/:id/submissions` and `/homework/:id/submissions/:sid/grade` share one controller (the grade screen is pushed on top).
class SubmissionsBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<SubmissionsController>(() => SubmissionsController(assignmentId: Get.parameters['id'] ?? ''));
  }
}
