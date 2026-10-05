import 'package:get/get.dart';
import '../../../core/network/base_client.dart';
import '../../../core/network/dio_service.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/services/permission_service.dart';
import '../../modules/auth/controllers/auth_controller.dart';

/// Wires up the app's global, app-lifetime singletons - the network layer
/// and the session state (+ permissions) every feature depends on.
/// Everything else is bound per-feature/per-route instead.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthApiService>(AuthApiService(BaseClient()), permanent: true);
    final permissions = Get.put<PermissionService>(PermissionService(), permanent: true);

    final auth = Get.put<AuthController>(
      AuthController(api: Get.find<AuthApiService>(), permissions: permissions),
      permanent: true,
    );
    DioService.onUnauthorized = auth.logout;
  }
}
