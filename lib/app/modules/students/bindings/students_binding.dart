import 'package:get/get.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/students_controller.dart';

class StudentsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
    Get.lazyPut<StudentsController>(() => StudentsController(), fenix: true);
  }
}
