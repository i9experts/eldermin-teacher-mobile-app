import '../../../../core/design/motion/splash_timeline.dart';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/constants/login_config.dart';
import '../../../../core/models/auth_me.dart';
import '../../../../core/models/institution.dart';
import '../../../../core/models/staff_me.dart';
import '../../../../core/models/teacher_user.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/post_login_hooks.dart';
import '../../../../core/services/token_store.dart';
import '../../../../core/utils/jwt_claims.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../utils/toast_util.dart';
import '../../../../core/network/server_states.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Roles allowed to use the app. v1: teachers only. This is a plain,
/// injectable allow-list so coordinators etc. can be added later by
/// changing one constant (and extending `PermissionSet.rolePermissions`).
const Set<String> kAllowedRoles = {'teacher'};

/// Re-fetch `/staff-portal/me` on app resume at most this often (owner
/// decision B) so a class-teacher assignment change shows up without a
/// re-login.
const Duration kProfileRefreshInterval = Duration(minutes: 10);

/// Longest a profile re-read may take before it is abandoned (the last good profile stays).
const Duration kProfileRefreshDeadline = Duration(seconds: 20);

const String kSessionExpiredMessage = 'Session expired, please sign in again';

/// The sign-in notice after the server rejected the session because the staff account was deactivated (401 "This account is no longer active.").
const String kAccountInactiveMessage = 'Your account is no longer active. Please contact your school.';

/// Global session state - the single source of truth for whether the app
/// shows the intro / login flow or the home shell. Registered once
/// (permanent) in InitialBinding so it survives for the whole app lifetime.
///
/// Identity rule: staffId / teacherProfileId come ONLY from
/// `GET /staff-portal/me` (never from JWT claims - old tokens lack them).
class AuthController extends GetxController with WidgetsBindingObserver {
  AuthController({
    required AuthApiService api,
    required PermissionService permissions,
    TokenStore tokenStore = const SecureTokenStore(),
    Set<String> allowedRoles = kAllowedRoles,
    Duration minSplash = EmSplashTimeline.minHold,
    Future<void> Function()? resetScopedControllers,
    DateTime Function()? clock,
    Duration refreshInterval = kProfileRefreshInterval,
    Future<void> Function(StaffMe profile) postLoginHook = PostLoginHooks.run,
    void Function(String message)? notify,
  })  : _api = api,
        _permissions = permissions,
        _tokens = tokenStore,
        _allowedRoles = allowedRoles,
        _minSplash = minSplash,
        _resetScopedControllers = resetScopedControllers ?? _defaultReset,
        _clock = clock ?? DateTime.now,
        _refreshInterval = refreshInterval,
        _postLoginHook = postLoginHook,
        _notify = notify ?? ToastUtil.showToast;

  final AuthApiService _api;
  final PermissionService _permissions;
  final TokenStore _tokens;
  final Set<String> _allowedRoles;
  final Duration _minSplash;
  final Future<void> Function() _resetScopedControllers;
  final DateTime Function() _clock;
  final Duration _refreshInterval;
  final Future<void> Function(StaffMe profile) _postLoginHook;
  final void Function(String message) _notify;

  final status = AuthStatus.unknown.obs;

  /// Whether the first-launch intro has been shown (loaded during bootstrap).
  final introSeen = true.obs;

  /// Identity for the whole session; null until the profile is resolved
  /// (or, for an unsupported role, holds only what the session check returned).
  final user = Rxn<TeacherUser>();
  final institution = Rxn<Institution>();

  /// Full `GET /staff-portal/me` result (null for unsupported roles).
  final staffMe = Rxn<StaffMe>();

  /// False when the signed-in role is not in the allow-list.
  final roleSupported = true.obs;

  final profileLoading = false.obs;
  final profileError = RxnString();

  /// True while a token deep-link is being validated (UI shows a loader).
  final tokenLoginInProgress = false.obs;

  /// One-shot message for the login screen (failed token link, expired
  /// session at launch). The screen clears it once shown/edited.
  final loginNotice = RxnString();

  DateTime? _lastProfileSync;
  bool _refreshing = false;

  // ── class claims of the stored token (multi-section class teachers) ──
  JwtClaims _claims = JwtClaims.empty;

  /// Keys ([ClassRef.key]) of class-teacher classes of `/staff-portal/me` that the token's claims do not cover (the token predates the
  /// assignment; the backend would answer 403 on attendance), plus classes the backend refused with that 403. Empty when the token has no
  /// class claims at all (the backend is unrestricted then) or for a non-class-teacher.
  final staleClassKeys = <String>{}.obs;
  final _deniedClassKeys = <String>{};

  /// The class the teacher last chose on the attendance screen (session only, never persisted; cleared on sign-out).
  final attendanceClassKey = RxnString();

  bool get reauthRequired => staleClassKeys.isNotEmpty;
  bool isClassStale(ClassRef c) => staleClassKeys.toList().contains(c.key); // toList registers the Obx dependency

  /// The backend answered 403 "class teacher of your own assigned class only" for [c]: treat it exactly like a stale claim.
  void markClassDenied(ClassRef c) {
    _deniedClassKeys.add(c.key);
    staleClassKeys.add(c.key);
  }

  void _setClaimsFrom(String? token) {
    _claims = JwtClaims.parse(token);
    _deniedClassKeys.clear();
  }

  void _recomputeStale(StaffMe? me) {
    final missing = {for (final c in _claims.missingFrom(classTeacherClasses(me?.teacherProfile))) c.key};
    staleClassKeys
      ..clear()
      ..addAll(missing)
      ..addAll(_deniedClassKeys);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    bootstrap();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshProfile();
  }

  /// What the profile-load / sign-in screens say for a failed `/auth/me` or `/staff-portal/me`: a 403 is "you don't have access" (never the raw
  /// "Forbidden resource"); everything else keeps the network layer's message (offline, timeout, server text).
  static String profileMessageFor(ApiException e) =>
      e.statusCode == 403 ? "You don't have access to Eldermin Teacher with this account. Ask your school administrator if you think this is a mistake." : e.message;

  bool roleAllowed(String? role) => role != null && _allowedRoles.contains(role);

  bool get isClassTeacher => staffMe.value?.isClassTeacher ?? false;
  String? get staffId => staffMe.value?.staffId;
  String? get teacherProfileId => staffMe.value?.teacherProfileId;

  /// Restores a stored session (token -> /auth/me -> /staff-portal/me) or
  /// falls to login. Never leaves the app on the splash screen.
  Future<void> bootstrap() async {
    final minSplash = Future<void>.delayed(_minSplash);
    if (!LoginConfig.showSchoolCode) {
      // An older install may still hold a remembered school code: drop it so it can never be sent or prefilled again.
      try {
        await AppPreferences.clearSchoolSlug();
      } catch (_) {}
    }
    try {
      introSeen.value = await AppPreferences.isIntroSeen();
    } catch (_) {
      introSeen.value = true; // never block sign-in on a prefs failure
    }
    final token = await _tokens.readToken();
    if (token == null || token.isEmpty) {
      await minSplash;
      if (status.value == AuthStatus.unknown) status.value = AuthStatus.unauthenticated;
      return;
    }
    _setClaimsFrom(token);
    final ok = await _restore();
    await minSplash;
    if (status.value == AuthStatus.unknown) {
      if (ok || profileError.value != null) {
        // Offline / server error keeps the session (retry screen), it is
        // NOT a logout.
        status.value = AuthStatus.authenticated;
      } else {
        // Rejected (401) and the global hook did not run: drop the token.
        await _clearSession();
        status.value = AuthStatus.unauthenticated;
      }
    }
  }

  /// Retry from the profile-load error screen.
  Future<bool> retryRestore() => _restore();

  /// Session check with the stored token, then the staff profile.
  Future<bool> _restore() async {
    profileLoading.value = true;
    profileError.value = null;
    try {
      final me = await _api.fetchAuthMe();
      if (!roleAllowed(me.role)) {
        _applyUnsupported(_userFromAuthMe(me), null);
        return true;
      }
    } on ApiException catch (e) {
      profileLoading.value = false;
      if (e.statusCode == 401) return false; // global handler logs out
      profileError.value = profileMessageFor(e);
      return false;
    } catch (_) {
      profileLoading.value = false;
      profileError.value = 'Something went wrong. Please try again.';
      return false;
    }
    return loadProfile();
  }

  /// Signs in. Throws [ApiException] (e.g. 401 invalid credentials) so the
  /// login form can show the message; never triggers logout itself.
  Future<void> login({required String email, required String password, String? slug}) async {
    // School code off (see login_config.dart): never send one, whatever the caller passed.
    final effectiveSlug = LoginConfig.showSchoolCode ? slug : null;
    final result = await _api.login(email: email, password: password, slug: effectiveSlug);
    await _completeSignIn(result.accessToken, result.user, result.institution);
    final trimmed = effectiveSlug?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppPreferences.clearSchoolSlug();
    } else {
      await AppPreferences.saveSchoolSlug(trimmed);
    }
  }

  /// Deep-link auto-login (web parity `/login?token=&slug=`): the token is
  /// validated against `GET /auth/me` BEFORE it is stored anywhere. Returns
  /// true on success; on failure sets [loginNotice] and returns false.
  Future<bool> signInWithToken({required String token, required String slug}) async {
    tokenLoginInProgress.value = true;
    loginNotice.value = null;
    try {
      final AuthMe me;
      try {
        me = await _api.fetchAuthMe(token: token);
      } on ApiException catch (e) {
        loginNotice.value = e.statusCode == 401
            ? 'This sign-in link is invalid or has expired. Please sign in with your email and password.'
            : e.message;
        return false;
      }
      final basic = _userFromAuthMe(me);
      final inst = Institution(slug: slug);
      try {
        await _completeSignIn(token, basic, inst);
      } on ApiException catch (e) {
        loginNotice.value = e.message;
        return false;
      }
      if (LoginConfig.showSchoolCode) await AppPreferences.saveSchoolSlug(slug);
      return true;
    } catch (_) {
      loginNotice.value = 'Something went wrong. Please sign in manually.';
      return false;
    } finally {
      tokenLoginInProgress.value = false;
    }
  }

  /// Stores the (already validated) token and resolves the profile.
  Future<void> _completeSignIn(String token, TeacherUser basic, Institution inst) async {
    await _tokens.saveToken(token);
    _setClaimsFrom(token);
    loginNotice.value = null;

    if (!roleAllowed(basic.role)) {
      // Unsupported role: keep only what login returned; do not call
      // staff-portal (it is meaningless for non-teacher roles).
      _applyUnsupported(basic, inst);
      status.value = AuthStatus.authenticated;
      return;
    }

    roleSupported.value = true;
    final ok = await loadProfile();
    if (!ok) {
      // Sign-in must not leave a half-built session: drop the token and
      // let the caller show why.
      final message = profileError.value ?? 'Could not load your profile. Please try again.';
      await _tokens.clearAll();
      user.value = null;
      institution.value = null;
      profileError.value = null;
      throw ApiException(message);
    }
    status.value = AuthStatus.authenticated;
    final me = staffMe.value;
    if (me != null) {
      try {
        await _postLoginHook(me);
      } catch (_) {/* a hook must never break sign-in */}
    }
  }

  /// Fetches `/staff-portal/me` and applies it. Returns true on success.
  /// Failure leaves [profileError] set (UI shows a retry screen); a 401
  /// is handled globally by DioService -> [handleUnauthorized].
  Future<bool> loadProfile() async {
    profileLoading.value = true;
    profileError.value = null;
    try {
      final me = await _api.fetchStaffMe();
      _applyMe(me);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return false; // logout already triggered
      profileError.value = profileMessageFor(e);
      return false;
    } catch (_) {
      profileError.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      profileLoading.value = false;
    }
  }

  /// Silent re-fetch of `/staff-portal/me` so class-teacher / profile
  /// changes propagate without a re-login (owner decision B). Resume calls
  /// it throttled (once per [kProfileRefreshInterval]); pull-to-refresh
  /// passes [force]. Failures are ignored - the last good profile stays.
  Future<void> refreshProfile({bool force = false}) async {
    if (status.value != AuthStatus.authenticated || !roleSupported.value || staffMe.value == null) return;
    if (_refreshing) return;
    final last = _lastProfileSync;
    if (!force && last != null && _clock().difference(last) < _refreshInterval) return;
    _refreshing = true;
    try {
      // Bounded: a hung server must not keep `_refreshing` set (it would block every later refresh).
      _applyMe(await _api.fetchStaffMe().timeout(kProfileRefreshDeadline));
    } catch (_) {
      // Offline / transient: keep what we have. A 401 is handled globally.
    } finally {
      _refreshing = false;
    }
  }

  void _applyMe(StaffMe me) {
    _lastProfileSync = _clock();
    if (!roleAllowed(me.user.role)) {
      _applyUnsupported(me.user, me.institution);
      return;
    }
    _recomputeStale(me);
    final current = staffMe.value;
    if (current != null && jsonEncode(current.toJson()) == jsonEncode(me.toJson())) return;
    roleSupported.value = true;
    _permissions.update(me.user, me.institution); // before the Rx that triggers rebuilds
    staffMe.value = me;
    user.value = me.user;
    institution.value = me.institution;
  }

  /// A new profile photo was uploaded (`POST /auth/me/avatar` answered `{avatarUrl}`): updates the in-memory session user and staff identity so the
  /// app bar shows it at once. Nothing is persisted (the user is rebuilt from the server on every launch); the next `/staff-portal/me` carries the same URL.
  void setAvatarUrl(String url) {
    final u = user.value;
    if (u != null) user.value = u.copyWith(avatarUrl: url);
    final me = staffMe.value;
    if (me != null) {
      staffMe.value = StaffMe(
        user: me.user.copyWith(avatarUrl: url),
        staffId: me.staffId,
        teacherProfileId: me.teacherProfileId,
        teacherProfile: me.teacherProfile,
        department: me.department,
        campus: me.campus,
        institution: me.institution,
      );
    }
  }

  void _applyUnsupported(TeacherUser basic, Institution? inst) {
    user.value = basic;
    institution.value = inst;
    staffMe.value = null;
    roleSupported.value = false;
    _permissions.update(null, null);
  }

  TeacherUser _userFromAuthMe(AuthMe me) =>
      TeacherUser(id: me.id, name: me.name, email: me.email, role: me.role, avatarUrl: me.avatarUrl);

  /// Called by the network layer on a 401 from an authenticated request
  /// (never from login / forgot / reset - those are not session expiry).
  Future<void> handleUnauthorized() async {
    final wasBootstrapping = status.value == AuthStatus.unknown;
    if (status.value == AuthStatus.unauthenticated) return;
    await logout();
    if (wasBootstrapping) {
      loginNotice.value = kSessionExpiredMessage; // no overlay yet at launch
    } else {
      _notify(kSessionExpiredMessage);
    }
  }

  /// A 401 "This account is no longer active." on an authenticated call (deactivated staff): sign out to the login screen with a notice that
  /// stays there (not a toast that vanishes with the shell).
  Future<void> handleAccountInactive() async {
    if (status.value == AuthStatus.unauthenticated) return;
    await logout();
    loginNotice.value = kAccountInactiveMessage;
  }

  /// The server's message when the school is suspended (403 SCHOOL_SUSPENDED on an authenticated call) - the app then shows a clean
  /// full-screen state with only "Log out". Null while the school is active. A suspended answer at sign-in stays on the login form.
  final schoolSuspendedMessage = RxnString();

  void handleSchoolSuspended(String message) {
    if (status.value == AuthStatus.unauthenticated) return;
    schoolSuspendedMessage.value = message.trim().isEmpty ? ServerStates.suspendedFallback : message.trim();
    // a screen pushed on top of the shell (a form, a detail) must not stay above the suspended state
    try {
      Get.until((r) => r.isFirst);
    } catch (_) {}
  }

  /// Full sign-out: wipes secure storage + preferences, in-memory
  /// session, permissions and per-route GetX controllers.
  Future<void> logout() async {
    if (status.value == AuthStatus.unauthenticated && user.value == null) return;
    final token = await _tokens.readToken();
    if (token != null) {
      // Best-effort, stateless on the server - do not wait on it for UX.
      _api.logout();
    }
    await _clearSession();
    status.value = AuthStatus.unauthenticated;
    // After the shell has been swapped out, drop non-permanent controllers.
    await _resetScopedControllers();
  }

  Future<void> _clearSession() async {
    await _tokens.clearAll();
    user.value = null;
    institution.value = null;
    staffMe.value = null;
    roleSupported.value = true;
    profileError.value = null;
    profileLoading.value = false;
    _lastProfileSync = null;
    schoolSuspendedMessage.value = null;
    _claims = JwtClaims.empty;
    _deniedClassKeys.clear();
    staleClassKeys.clear();
    attendanceClassKey.value = null;
    _permissions.clear();
  }

  static Future<void> _defaultReset() async {
    await WidgetsBinding.instance.endOfFrame;
    Get.deleteAll(); // force:false -> permanent singletons survive
  }
}
