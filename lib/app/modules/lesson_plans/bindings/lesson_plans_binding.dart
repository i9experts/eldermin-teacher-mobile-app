import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/services/lesson_plan_repository.dart';
import '../controllers/lesson_plan_detail_controller.dart';
import '../controllers/lesson_plan_form_controller.dart';
import '../controllers/lesson_plan_upload_controller.dart';
import '../controllers/lesson_plans_controller.dart';

void _shared() {
  if (!Get.isRegistered<LessonPlanRepository>()) Get.lazyPut<LessonPlanRepository>(() => LessonPlanRepository(), fenix: true);
  if (!Get.isRegistered<LessonPlansController>()) Get.lazyPut<LessonPlansController>(() => LessonPlansController(), fenix: true);
}

/// `/lesson-plans`: the list (`Get.arguments` may be a status such as `'rejected'` to open pre-filtered).
class LessonPlansBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/lesson-plans/new`: create; edit and / or a parsed draft arrive through `Get.arguments`.
class LessonPlanFormBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final a = Get.arguments;
    final args = a is LessonPlanFormArgs ? a : LessonPlanFormArgs(editing: a is LessonPlanRecord ? a : null, draft: a is LessonPlanDraft ? a : null);
    Get.lazyPut<LessonPlanFormController>(() => LessonPlanFormController(editing: args.editing, draft: args.draft));
  }
}

/// `/lesson-plans/:id`.
class LessonPlanDetailBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<LessonPlanDetailController>(() => LessonPlanDetailController(id: Get.parameters['id'] ?? ''));
  }
}

/// `/lesson-plans/upload`.
class LessonPlanUploadBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<LessonPlanUploadController>(() => LessonPlanUploadController());
  }
}
