import 'package:get/get.dart';
import '../controllers/ptm_controller.dart';

class PtmBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PtmController>(() => PtmController(), fenix: true);
  }
}
