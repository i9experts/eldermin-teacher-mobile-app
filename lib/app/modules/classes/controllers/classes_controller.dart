import 'package:get/get.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/services/permission_service.dart';
import '../../../common/module_catalog.dart';
import '../../auth/controllers/auth_controller.dart';

/// Permission-filtered entries for the Classes tab.
class ClassesController extends GetxController {
  List<ModuleEntry> get entries => ModuleCatalog.visible(
        ModulePlacement.classes,
        Get.find<PermissionService>(),
        isClassTeacher: Get.find<AuthController>().isClassTeacher,
      );

  /// MY classes (class-teacher class + assignments) from `/staff-portal/me`.
  List<ClassRef> get classes => teacherClassesOf(Get.find<AuthController>().staffMe.value?.teacherProfile);
}
