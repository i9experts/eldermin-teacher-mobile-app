import 'package:get/get.dart';
import '../../../../core/services/ptm_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/ptm_controller.dart';
import '../controllers/ptm_create_controller.dart';

void ensurePtmRepository() {
  if (!Get.isRegistered<PtmRepository>()) Get.lazyPut<PtmRepository>(() => PtmRepository(), fenix: true);
}

/// `/ptm`. The list controller is NOT fenix: it only exists while the list is open, so the detail and create screens update it in place
/// when it is there and never wake a list load of their own (a notification can open `/ptm/:id` directly).
class PtmBinding extends Bindings {
  @override
  void dependencies() {
    ensurePtmRepository();
    Get.lazyPut<PtmController>(() => PtmController());
  }
}

/// `/ptm/:id`: the screen creates its own tagged detail controller; it only needs the repository (and a list controller to update, if any).
class PtmDetailBinding extends Bindings {
  @override
  void dependencies() {
    ensurePtmRepository();
  }
}

/// `/ptm/new`.
class PtmCreateBinding extends Bindings {
  @override
  void dependencies() {
    ensurePtmRepository();
    if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
    Get.lazyPut<PtmCreateController>(() => PtmCreateController());
  }
}
