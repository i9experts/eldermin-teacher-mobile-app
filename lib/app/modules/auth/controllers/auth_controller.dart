import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/institution.dart';
import '../../../../core/models/staff_me.dart';
import '../../../../core/models/teacher_user.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/token_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Roles allowed to use the app. v1: teachers only. This is a plain,
/// injectable allow-list so coordinators etc. can be added later by
/// changing one constant (and extending `PermissionSet.rolePermissions`).
const Set<String> kAllowedRoles = {'teacher'};

/// Global session state - the single source of truth for whether the app
/// shows the login flow or the home shell. Registered once (permanent) in
/// InitialBinding so it survives for the whole app lifetime.
///
/// Identity rule: staffId / teacherProfileId come ONLY from
/// `GET /staff-portal/me` (never from JWT claims - old tokens lack them).
class AuthController extends GetxController {
  AuthController({
    required AuthApiService api,
    required PermissionService permissions,
    TokenStore tokenStore = const SecureTokenStore(),
    Set<String> allowedRoles = kAllowedRoles,
    Duration minSplash = const Duration(milliseconds: 1500),
    Future<void> Function()? resetScopedControllers,
  })  : _api = api,
        _permissions = permissions,
        _tokens = tokenStore,
        _allowedRoles = allowedRoles,
        _minSplash = minSplash,
        _resetScopedControllers = resetScopedControllers ?? _defaultReset;

  final AuthApiService _api;
  final PermissionService _permissions;
  final TokenStore _tokens;
  final Set<String> _allowedRoles;
  final Duration _minSplash;
  final Future<void> Function() _resetScopedControllers;

  final status = AuthStatus.unknown.obs;

  /// Identity for the whole session; null until the profile is resolved
  /// (or, for an unsupported role, holds only what login returned).
  final user = Rxn<TeacherUser>();
  final institution = Rxn<Institution>();

  /// Full `GET /staff-portal/me` result (null for unsupported roles).
  final staffMe = Rxn<StaffMe>();

  /// False when the signed-in role is not in the allow-list.
  final roleSupported = true.obs;

  final profileLoading = false.obs;
  final profileError = RxnString();

  @override
  void onInit() {
    super.onInit();
    bootstrap();
  }

  bool roleAllowed(String? role) => role != null && _allowedRoles.contains(role);

  bool get isClassTeacher => staffMe.value?.isClassTeacher ?? false;
  String? get staffId => staffMe.value?.staffId;
  String? get teacherProfileId => staffMe.value?.teacherProfileId;

  /// Restores a stored session (token -> profile) or falls to login.
  Future<void> bootstrap() async {
    final minSplash = Future<void>.delayed(_minSplash);
    final token = await _tokens.readToken();
    if (token == null || token.isEmpty) {
      await minSplash;
      status.value = AuthStatus.unauthenticated;
      return;
    }
    // Authenticated as far as we know; the profile fetch below is what
    // confirms it (a 401 triggers logout through DioService).
    final ok = await loadProfile();
    await minSplash;
    if (status.value == AuthStatus.unknown) {
      // loadProfile may already have logged out (401) - only set if undecided.
      status.value = ok || profileError.value != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
  }

  /// Signs in. Throws [ApiException] (e.g. 401 invalid credentials) so the
  /// login form can show the message; never triggers logout itself.
  Future<void> login({required String email, required String password, String? slug}) async {
    final result = await _api.login(email: email, password: password, slug: slug);
    await _tokens.saveToken(result.accessToken);

    if (!roleAllowed(result.user.role)) {
      // Unsupported role: keep only what login returned; do not call
      // staff-portal (it is meaningless for non-teacher roles).
      user.value = result.user;
      institution.value = result.institution;
      staffMe.value = null;
      roleSupported.value = false;
      _permissions.update(null, null);
      status.value = AuthStatus.authenticated;
      return;
    }

    roleSupported.value = true;
    final ok = await loadProfile();
    if (!ok) {
      // Sign-in must not leave a half-built session: drop the token and
      // let the login form show why.
      final message = profileError.value ?? 'Could not load your profile. Please try again.';
      await _tokens.clearAll();
      user.value = null;
      institution.value = null;
      profileError.value = null;
      throw ApiException(message);
    }
    status.value = AuthStatus.authenticated;
  }

  /// Fetches `/staff-portal/me` and applies it. Returns true on success.
  /// Failure leaves [profileError] set (UI shows a retry screen); a 401
  /// is handled globally by DioService -> [logout].
  Future<bool> loadProfile() async {
    profileLoading.value = true;
    profileError.value = null;
    try {
      final me = await _api.fetchStaffMe();
      if (!roleAllowed(me.user.role)) {
        user.value = me.user;
        institution.value = me.institution;
        staffMe.value = null;
        roleSupported.value = false;
        _permissions.update(null, null);
        return true;
      }
      roleSupported.value = true;
      _permissions.update(me.user, me.institution); // before the Rx that triggers rebuilds
      staffMe.value = me;
      user.value = me.user;
      institution.value = me.institution;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return false; // logout already triggered
      profileError.value = e.message;
      return false;
    } catch (_) {
      profileError.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      profileLoading.value = false;
    }
  }

  /// Full sign-out: wipes secure storage + preferences, in-memory
  /// session, permissions and per-route GetX controllers. Also what a
  /// global 401 calls.
  Future<void> logout() async {
    if (status.value == AuthStatus.unauthenticated && user.value == null) return;
    final token = await _tokens.readToken();
    if (token != null) {
      // Best-effort, stateless on the server - do not wait on it for UX.
      _api.logout();
    }
    await _tokens.clearAll();
    user.value = null;
    institution.value = null;
    staffMe.value = null;
    roleSupported.value = true;
    profileError.value = null;
    _permissions.clear();
    status.value = AuthStatus.unauthenticated;
    // After the shell has been swapped out, drop non-permanent controllers.
    await _resetScopedControllers();
  }

  static Future<void> _defaultReset() async {
    await WidgetsBinding.instance.endOfFrame;
    Get.deleteAll(); // force:false -> permanent singletons survive
  }
}
