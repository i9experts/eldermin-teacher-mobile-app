import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/services/permission_service.dart';
import '../common/module_catalog.dart';
import '../modules/auth/controllers/auth_controller.dart';
import 'app_routes.dart';

/// Why a location may or may not be opened. ONE rule set, shared with the Classes / More entries: the module's [ModuleEntry.isVisibleTo]
/// (permission + class-teacher + enabled-in-v1). The web gates menu/routes on institution.activeModules (Sidebar.tsx moduleId via hasModule; ProtectedRoute `module`); the app
/// intentionally does not in v1 - visibility is by permissions only - pending an owner decision (see PermissionService). Locations that belong to no module (messages, notifications, profile, help, about, delete account) only need a signed-in,
/// supported teacher with a resolved profile.
class RouteGuardRules {
  RouteGuardRules._();

  /// Routes that must keep working without a session (or before the profile exists).
  static const Set<String> publicRoutes = {
    Routes.splash,
    Routes.login,
    Routes.unsupportedRole,
    Routes.intro,
    Routes.forgotPassword,
    Routes.resetPassword,
    Routes.notAvailable,
  };

  static bool isPublic(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return publicRoutes.contains(path);
  }

  static bool allows(
    String location, {
    required bool signedIn,
    required bool roleSupported,
    required bool profileLoaded,
    required PermissionService permissions,
    required bool isClassTeacher,
  }) {
    if (isPublic(location)) return true;
    if (!signedIn || !roleSupported || !profileLoaded) return false;
    final entry = ModuleCatalog.entryForRoute(location);
    return entry == null || entry.isVisibleTo(permissions, isClassTeacher: isClassTeacher);
  }

  /// [allows] for the live session (AuthController + PermissionService registered in GetX). Anything missing means "not allowed".
  static bool allowsNow(String location) {
    if (isPublic(location)) return true;
    if (!Get.isRegistered<AuthController>() || !Get.isRegistered<PermissionService>()) return false;
    final auth = Get.find<AuthController>();
    return allows(
      location,
      signedIn: auth.status.value == AuthStatus.authenticated,
      roleSupported: auth.roleSupported.value,
      profileLoaded: auth.staffMe.value != null,
      permissions: Get.find<PermissionService>(),
      isClassTeacher: auth.isClassTeacher,
    );
  }
}

/// Attached to every page in [AppPages] except the public ones. Covers every way of reaching a route (taps, notification targets, deep links),
/// because all of them go through named navigation. A blocked location is replaced by the "Not available for your account" screen.
class RouteGuard extends GetMiddleware {
  RouteGuard() : super(priority: -100);

  @override
  RouteSettings? redirect(String? route) {
    if (route == null || RouteGuardRules.allowsNow(route)) return null;
    return const RouteSettings(name: Routes.notAvailable);
  }
}
