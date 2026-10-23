import 'package:get/get.dart';
import '../../../../core/services/early_years_repository.dart';
import '../controllers/early_years_controller.dart';

void _shared() {
  if (!Get.isRegistered<EarlyYearsRepository>()) Get.lazyPut<EarlyYearsRepository>(() => EarlyYearsRepository(), fenix: true);
  Get.lazyPut<EarlyYearsController>(() => EarlyYearsController(), fenix: true);
}

/// `/early-years`.
class EarlyYearsBinding extends Bindings {
  @override
  void dependencies() => _shared();
}
