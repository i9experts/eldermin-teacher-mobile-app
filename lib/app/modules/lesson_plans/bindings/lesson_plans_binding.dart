import 'package:get/get.dart';
import '../controllers/lesson_plans_controller.dart';

class LessonPlansBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LessonPlansController>(() => LessonPlansController(), fenix: true);
  }
}
