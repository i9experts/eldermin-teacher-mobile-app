import 'package:get/get.dart';
import '../controllers/student_leaves_controller.dart';

class StudentLeavesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StudentLeavesController>(() => StudentLeavesController(), fenix: true);
  }
}
