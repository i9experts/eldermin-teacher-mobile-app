import 'package:get/get.dart';
import '../../../../core/services/syllabus_repository.dart';
import '../controllers/syllabus_controller.dart';
import '../controllers/syllabus_detail_controller.dart';
import '../controllers/weekly_planner_controller.dart';

void _shared() {
  if (!Get.isRegistered<SyllabusRepository>()) Get.lazyPut<SyllabusRepository>(() => SyllabusRepository(), fenix: true);
  if (!Get.isRegistered<SyllabusController>()) Get.lazyPut<SyllabusController>(() => SyllabusController(), fenix: true);
}

/// `/syllabus`.
class SyllabusBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/syllabus/:id`.
class SyllabusDetailBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<SyllabusDetailController>(() => SyllabusDetailController(id: Get.parameters['id'] ?? ''));
  }
}

/// `/syllabus/weekly-planner`.
class WeeklyPlannerBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<WeeklyPlannerController>(() => WeeklyPlannerController());
  }
}
