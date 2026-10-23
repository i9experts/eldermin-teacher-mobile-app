import 'package:get/get.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../controllers/early_years_child_controller.dart';
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

/// `/early-years/child/:id` (an [EceChild] in `arguments` skips the lookup in the list).
class EarlyYearsChildBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<EarlyYearsChildController>(() => EarlyYearsChildController(childId: Get.parameters['id'] ?? '', initial: arg is EceChild ? arg : null));
  }
}
