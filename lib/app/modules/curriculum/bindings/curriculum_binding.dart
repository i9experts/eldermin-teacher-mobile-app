import 'package:get/get.dart';
import '../../../../core/services/reference_repository.dart';
import '../controllers/curriculum_controller.dart';

void _shared() {
  if (!Get.isRegistered<ReferenceRepository>()) Get.lazyPut<ReferenceRepository>(() => ReferenceRepository(), fenix: true);
  if (!Get.isRegistered<CurriculumController>()) Get.lazyPut<CurriculumController>(() => CurriculumController(), fenix: true);
}

/// `/curriculum`.
class CurriculumBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/curriculum/:id`.
class CurriculumDetailBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<CurriculumDetailController>(() => CurriculumDetailController(id: Get.parameters['id'] ?? ''));
  }
}
