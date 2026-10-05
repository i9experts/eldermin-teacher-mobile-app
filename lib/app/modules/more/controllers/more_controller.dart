import 'package:get/get.dart';
import '../../../../core/services/permission_service.dart';
import '../../../common/module_catalog.dart';
import '../../auth/controllers/auth_controller.dart';

/// Permission-filtered entries for the More tab, plus sign-out.
class MoreController extends GetxController {
  List<ModuleEntry> get entries => ModuleCatalog.visible(
        ModulePlacement.more,
        Get.find<PermissionService>(),
        isClassTeacher: Get.find<AuthController>().isClassTeacher,
      );

  Future<void> logout() => Get.find<AuthController>().logout();
}
