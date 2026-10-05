import 'package:get/get.dart';
import '../../../../core/services/home_repository.dart';
import '../controllers/timetable_controller.dart';

class TimetableBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HomeRepository>()) Get.lazyPut<HomeRepository>(() => HomeRepository(), fenix: true);
    Get.lazyPut<TimetableController>(() => TimetableController(), fenix: true);
  }
}
