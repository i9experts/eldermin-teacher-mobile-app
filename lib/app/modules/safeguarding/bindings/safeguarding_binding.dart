import 'package:get/get.dart';
import '../../../../core/services/safeguarding_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/safeguarding_controller.dart';

/// `/safeguarding`. The controller is NOT kept alive (no `fenix`): leaving the screen disposes it and wipes the typed concern.
class SafeguardingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SafeguardingRepository>()) Get.lazyPut<SafeguardingRepository>(() => SafeguardingRepository(), fenix: true);
    if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
    Get.lazyPut<SafeguardingController>(() => SafeguardingController());
  }
}
