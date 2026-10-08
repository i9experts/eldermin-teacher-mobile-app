import 'package:get/get.dart';
import '../../messages/bindings/messages_binding.dart';
import '../controllers/student_leaves_controller.dart';

class StudentLeavesBinding extends Bindings {
  @override
  void dependencies() {
    ensureMessagingRepository();
    Get.lazyPut<StudentLeavesController>(() => StudentLeavesController(), fenix: true);
  }
}
