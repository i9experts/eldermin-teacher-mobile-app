import 'package:get/get.dart';
import '../controllers/early_years_controller.dart';

class EarlyYearsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EarlyYearsController>(() => EarlyYearsController(), fenix: true);
  }
}
