import 'package:get/get.dart';
import '../controllers/safeguarding_controller.dart';

class SafeguardingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SafeguardingController>(() => SafeguardingController(), fenix: true);
  }
}
