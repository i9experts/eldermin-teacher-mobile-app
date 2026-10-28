import 'package:get/get.dart';
import '../../../../core/services/early_years_repository.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../controllers/early_years_child_controller.dart';
import '../controllers/early_years_controller.dart';
import '../controllers/observation_form_controller.dart';
import '../controllers/portfolio_form_controller.dart';
import '../controllers/quick_observe_controller.dart';

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

/// `/early-years/child/:id/quick`.
class QuickObserveBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<QuickObserveController>(() => QuickObserveController(childId: Get.parameters['id'] ?? '', initial: arg is EceChild ? arg : null));
  }
}

/// `/early-years/child/:id/observe`.
class ObservationFormBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<ObservationFormController>(() => ObservationFormController(childId: Get.parameters['id'] ?? '', initial: arg is EceChild ? arg : null));
  }
}

/// `/early-years/child/:id/portfolio/new`.
class PortfolioFormBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    final arg = Get.arguments;
    Get.lazyPut<PortfolioFormController>(() => PortfolioFormController(childId: Get.parameters['id'] ?? '', initial: arg is EceChild ? arg : null));
  }
}
