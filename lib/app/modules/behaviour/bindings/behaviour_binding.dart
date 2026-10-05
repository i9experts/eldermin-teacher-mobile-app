import 'package:get/get.dart';
import '../controllers/behaviour_controller.dart';

class BehaviourBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BehaviourController>(() => BehaviourController(), fenix: true);
  }
}
