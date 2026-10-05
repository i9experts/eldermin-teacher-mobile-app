import 'package:get/get.dart';
import '../controllers/homework_controller.dart';

class HomeworkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeworkController>(() => HomeworkController(), fenix: true);
  }
}
