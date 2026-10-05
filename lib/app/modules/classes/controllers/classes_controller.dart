import 'package:get/get.dart';
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
}
