import 'package:get/get.dart';
import '../../../../core/services/reference_repository.dart';
import '../controllers/library_controller.dart';

class LibraryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ReferenceRepository>()) Get.lazyPut<ReferenceRepository>(() => ReferenceRepository(), fenix: true);
    Get.lazyPut<LibraryController>(() => LibraryController(), fenix: true);
  }
}
