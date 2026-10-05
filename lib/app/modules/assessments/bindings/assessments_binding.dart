import 'package:get/get.dart';
import '../controllers/assessments_controller.dart';

class AssessmentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AssessmentsController>(() => AssessmentsController(), fenix: true);
  }
}
