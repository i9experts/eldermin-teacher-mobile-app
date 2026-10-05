import 'package:get/get.dart';
import '../../../components/confirm_dialog.dart';
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

  /// Asks for confirmation, then performs the full sign-out.
  Future<void> confirmAndLogout() async {
    final ok = await ConfirmDialog.show(
      title: 'Sign out of Eldermin Teacher?',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok) await Get.find<AuthController>().logout();
  }
}
