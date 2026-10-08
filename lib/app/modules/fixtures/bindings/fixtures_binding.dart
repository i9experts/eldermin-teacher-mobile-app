import 'package:get/get.dart';
import '../../../../core/services/fixtures_repository.dart';
import '../controllers/fixtures_controller.dart';

class FixturesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<FixturesRepository>()) Get.lazyPut<FixturesRepository>(() => FixturesRepository(), fenix: true);
    Get.lazyPut<FixturesController>(() => FixturesController(), fenix: true);
  }
}
