import 'package:get/get.dart';
import '../controllers/curriculum_controller.dart';

class CurriculumBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CurriculumController>(() => CurriculumController(), fenix: true);
  }
}
