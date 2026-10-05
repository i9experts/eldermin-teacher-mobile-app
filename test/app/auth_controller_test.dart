import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:eldermin_teacher_app/core/services/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStore implements TokenStore {
  String? token;
  int clears = 0;
  _MemoryTokenStore([this.token]);
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async {
    token = null;
    clears++;
  }
}

class _FakeApi extends AuthApiService {
  _FakeApi() : super(BaseClient());

  LoginResult? loginResult;
  ApiException? loginError;
  StaffMe? me;
  ApiException? meError;
  AuthMe? authMe;
  ApiException? authMeError;
  String? lastAuthMeToken;
  int authMeCalls = 0;
  int meCalls = 0;
  int logoutCalls = 0;
  void Function()? onUnauthorizedHook;

  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AuthMe> fetchAuthMe({String? token}) async {
    authMeCalls++;
    lastAuthMeToken = token;
    if (authMeError != null) {
      if (authMeError!.statusCode == 401) onUnauthorizedHook?.call();
      throw authMeError!;
    }
    return authMe ?? AuthMe(id: 'u1', name: 'A', email: 'a@s.test', role: me?.user.role ?? 'teacher');
  }

  @override
  Future<StaffMe> fetchStaffMe() async {
    meCalls++;
    if (meError != null) throw meError!;
    return me!;
  }

  @override
  Future<void> logout() async => logoutCalls++;
}

StaffMe _staffMe({String role = 'teacher', bool classTeacher = false, String staffId = 'staff-from-me'}) =>
    StaffMe.fromJson({
      'user': {'id': 'u1', 'name': 'Amina Khan', 'email': 'a@s.test', 'role': role},
      'staffId': staffId,
      'teacherProfileId': 'tp-from-me',
      'teacherProfile': {'isClassTeacher': classTeacher},
      'department': 'Science',
      'campus': {'id': 'c1', 'name': 'Main'},
      'institution': {'slug': 's', 'activeModules': ['teaching']},
    });

LoginResult _login({String role = 'teacher'}) => LoginResult(
      accessToken: 'jwt-1',
      // A login payload that (wrongly) carries a different staffId must be ignored.
      user: TeacherUser(id: 'u1', name: 'A', email: 'a@s.test', role: role, staffId: 'staff-from-jwt'),
      institution: const Institution(slug: 's'),
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_secure_storage has no platform in unit tests.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );

  late _FakeApi api;
  late _MemoryTokenStore tokens;
  late PermissionService permissions;
  late int resets;

  late DateTime now;
  late List<String> toasts;
  late int hooks;

  AuthController make({String? token}) {
    tokens = _MemoryTokenStore(token);
    resets = 0;
    return AuthController(
      api: api,
      permissions: permissions,
      tokenStore: tokens,
      minSplash: Duration.zero,
      resetScopedControllers: () async => resets++,
      clock: () => now,
      postLoginHook: (_) async => hooks++,
      notify: toasts.add,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1, 9);
    toasts = [];
    hooks = 0;
    api = _FakeApi();
    permissions = PermissionService();
  });

  test('starts unknown, then unauthenticated when no token is stored', () async {
    final auth = make();
    expect(auth.status.value, AuthStatus.unknown);
    await auth.bootstrap();
    expect(auth.status.value, AuthStatus.unauthenticated);
    expect(api.meCalls, 0);
  });

  test('restores a stored session via GET /auth/me then GET /staff-portal/me', () async {
    api.me = _staffMe(classTeacher: true);
    final auth = make(token: 'stored');
    await auth.bootstrap();
    expect(auth.status.value, AuthStatus.authenticated);
    expect(api.authMeCalls, 1);
    expect(api.lastAuthMeToken, isNull); // stored token, sent by the network layer
    expect(api.meCalls, 1);
    expect(auth.staffId, 'staff-from-me');
    expect(auth.teacherProfileId, 'tp-from-me');
    expect(auth.isClassTeacher, isTrue);
    expect(auth.roleSupported.value, isTrue);
    expect(permissions.canAccess('teaching:view'), isTrue);
  });

  test('login takes staffId from /me, never from the login payload', () async {
    api.loginResult = _login();
    api.me = _staffMe();
    final auth = make();
    await auth.login(email: 'a@s.test', password: 'pw');
    expect(tokens.token, 'jwt-1');
    expect(auth.status.value, AuthStatus.authenticated);
    expect(auth.user.value!.staffId, 'staff-from-me');
    expect(auth.staffId, 'staff-from-me');
    expect(api.meCalls, 1);
  });

  test('invalid credentials surface to the caller and do not authenticate or log out', () async {
    api.loginError = ApiException('Invalid credentials', statusCode: 401);
    final auth = make();
    auth.status.value = AuthStatus.unauthenticated;
    await expectLater(auth.login(email: 'a', password: 'b'), throwsA(isA<ApiException>()));
    expect(auth.status.value, AuthStatus.unauthenticated);
    expect(tokens.clears, 0); // no logout side effects
    expect(api.logoutCalls, 0);
  });

  test('non-teacher role -> authenticated but unsupported, /me is not called', () async {
    api.loginResult = _login(role: 'parent');
    final auth = make();
    await auth.login(email: 'a', password: 'b');
    expect(auth.status.value, AuthStatus.authenticated);
    expect(auth.roleSupported.value, isFalse);
    expect(auth.staffMe.value, isNull);
    expect(api.meCalls, 0);
    expect(permissions.canAccess('dashboard:view'), isFalse);
  });

  test('allow-list is configurable (coordinator can be added later)', () async {
    api.loginResult = _login(role: 'coordinator');
    api.me = _staffMe(role: 'coordinator');
    tokens = _MemoryTokenStore();
    final auth = AuthController(
      api: api,
      permissions: permissions,
      tokenStore: tokens,
      allowedRoles: const {'teacher', 'coordinator'},
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
    );
    await auth.login(email: 'a', password: 'b');
    expect(auth.roleSupported.value, isTrue);
  });

  test('failed profile fetch after login clears the token and throws', () async {
    api.loginResult = _login();
    api.meError = ApiException("Couldn't reach Eldermin.");
    final auth = make();
    await expectLater(auth.login(email: 'a', password: 'b'), throwsA(isA<ApiException>()));
    expect(tokens.token, isNull);
    expect(auth.status.value, isNot(AuthStatus.authenticated));
  });

  test('network failure on restore stays authenticated with a retryable error', () async {
    api.meError = ApiException('No internet connection.');
    final auth = make(token: 'stored');
    await auth.bootstrap();
    expect(auth.status.value, AuthStatus.authenticated);
    expect(auth.staffMe.value, isNull);
    expect(auth.profileError.value, contains('No internet'));

    api.meError = null;
    api.me = _staffMe();
    expect(await auth.loadProfile(), isTrue);
    expect(auth.profileError.value, isNull);
    expect(auth.staffId, 'staff-from-me');
  });

  test('logout wipes storage, session, permissions and scoped controllers', () async {
    api.me = _staffMe();
    final auth = make(token: 'stored');
    await auth.bootstrap();
    await auth.logout();
    expect(tokens.token, isNull);
    expect(tokens.clears, 1);
    expect(auth.status.value, AuthStatus.unauthenticated);
    expect(auth.user.value, isNull);
    expect(auth.staffMe.value, isNull);
    expect(permissions.canAccess('teaching:view'), isFalse);
    expect(resets, 1);
    expect(api.logoutCalls, 1);
  });

  test('a 401 on restore ends the session (global hook), never stuck on splash', () async {
    api.authMeError = ApiException('Unauthorized', statusCode: 401);
    final c = make(token: 'stale');
    api.onUnauthorizedHook = c.handleUnauthorized; // what InitialBinding wires via DioService
    await c.bootstrap();
    expect(c.status.value, AuthStatus.unauthenticated);
    expect(tokens.token, isNull);
    expect(c.loginNotice.value, kSessionExpiredMessage); // no overlay at launch: shown on login
    expect(api.meCalls, 0);
  });

  test('a 401 on restore without the global hook still drops the token', () async {
    api.authMeError = ApiException('Unauthorized', statusCode: 401);
    final c = make(token: 'stale');
    await c.bootstrap();
    expect(c.status.value, AuthStatus.unauthenticated);
    expect(tokens.token, isNull);
  });

  test('offline at splash with a stored token -> retry screen state, NOT logout', () async {
    api.authMeError = ApiException('No internet connection.');
    final c = make(token: 'stored');
    await c.bootstrap();
    expect(c.status.value, AuthStatus.authenticated);
    expect(c.staffMe.value, isNull);
    expect(c.profileError.value, contains('No internet'));
    expect(tokens.token, 'stored');
    expect(tokens.clears, 0);

    api.authMeError = null;
    api.me = _staffMe();
    expect(await c.retryRestore(), isTrue);
    expect(c.profileError.value, isNull);
    expect(c.staffId, 'staff-from-me');
  });

  test('restoring a non-teacher session shows the unsupported-role state without calling /staff-portal/me', () async {
    api.authMe = const AuthMe(id: 'p', name: 'P', email: 'p@s.test', role: 'principal');
    final c = make(token: 'stored');
    await c.bootstrap();
    expect(c.status.value, AuthStatus.authenticated);
    expect(c.roleSupported.value, isFalse);
    expect(api.meCalls, 0);
  });

  test('401 from the login call is not a session expiry (no toast, no logout)', () async {
    api.loginError = ApiException('Invalid credentials', statusCode: 401);
    final c = make();
    c.status.value = AuthStatus.unauthenticated;
    await expectLater(c.login(email: 'a@s.test', password: 'bad'), throwsA(isA<ApiException>()));
    expect(toasts, isEmpty);
    expect(c.loginNotice.value, isNull);
  });

  test('401 on an authenticated request -> logout + "Session expired" toast', () async {
    api.me = _staffMe();
    final c = make(token: 'stored');
    await c.bootstrap();
    await c.handleUnauthorized();
    expect(c.status.value, AuthStatus.unauthenticated);
    expect(tokens.token, isNull);
    expect(toasts, [kSessionExpiredMessage]);
  });

  test('login remembers the school slug; blank slug forgets it', () async {
    api.loginResult = _login();
    api.me = _staffMe();
    final c = make();
    await c.login(email: 'a@s.test', password: 'pw', slug: ' demo-school ');
    expect(await AppPreferences.getSchoolSlug(), 'demo-school');
    await c.logout();
    // logout keeps the slug + intro flag (device conveniences)
    expect(await AppPreferences.getSchoolSlug(), 'demo-school');
    await c.login(email: 'a@s.test', password: 'pw', slug: '');
    expect(await AppPreferences.getSchoolSlug(), isNull);
  });

  test('post-login hook runs after login (and not for unsupported roles)', () async {
    api.loginResult = _login();
    api.me = _staffMe();
    final c = make();
    await c.login(email: 'a', password: 'b');
    expect(hooks, 1);

    api.loginResult = _login(role: 'principal');
    final c2 = make();
    await c2.login(email: 'a', password: 'b');
    expect(hooks, 1);
  });

  group('intro flag', () {
    test('bootstrap reads it; clearPreference (logout) keeps it and the slug', () async {
      SharedPreferences.setMockInitialValues({});
      final c = make();
      await c.bootstrap();
      expect(c.introSeen.value, isFalse);

      await AppPreferences.setIntroSeen();
      await AppPreferences.saveSchoolSlug('s');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('some_other_cached_thing', 'x');
      await AppPreferences.clearPreference();
      expect(await AppPreferences.isIntroSeen(), isTrue);
      expect(await AppPreferences.getSchoolSlug(), 's');
      expect((await SharedPreferences.getInstance()).getString('some_other_cached_thing'), isNull);

      final c2 = make();
      await c2.bootstrap();
      expect(c2.introSeen.value, isTrue);
    });
  });

  group('token deep-link sign-in', () {
    test('validates the token via /auth/me BEFORE storing it, then loads the profile', () async {
      api.authMe = const AuthMe(id: 'u1', name: 'A', email: 'a@s.test', role: 'teacher');
      api.me = _staffMe(classTeacher: true);
      final c = make();
      c.status.value = AuthStatus.unauthenticated;
      final ok = await c.signInWithToken(token: 'jwt.from.link', slug: 'demo-school');
      expect(ok, isTrue);
      expect(api.lastAuthMeToken, 'jwt.from.link');
      expect(tokens.token, 'jwt.from.link');
      expect(c.status.value, AuthStatus.authenticated);
      expect(c.isClassTeacher, isTrue);
      expect(c.tokenLoginInProgress.value, isFalse);
      expect(await AppPreferences.getSchoolSlug(), 'demo-school');
      expect(hooks, 1);
    });

    test('an invalid token never gets stored; clear error; stays unauthenticated', () async {
      api.authMeError = ApiException('Unauthorized', statusCode: 401);
      final c = make();
      c.status.value = AuthStatus.unauthenticated;
      final ok = await c.signInWithToken(token: 'bad.bad.bad', slug: 'demo-school');
      expect(ok, isFalse);
      expect(tokens.token, isNull);
      expect(c.status.value, AuthStatus.unauthenticated);
      expect(c.loginNotice.value, contains('invalid or has expired'));
      expect(c.tokenLoginInProgress.value, isFalse);
      expect(toasts, isEmpty); // 401 here is NOT a session expiry
    });

    test('non-teacher role goes through the same role gate (no /staff-portal/me)', () async {
      api.authMe = const AuthMe(id: 'p', name: 'P', email: 'p@s.test', role: 'principal');
      final c = make();
      c.status.value = AuthStatus.unauthenticated;
      expect(await c.signInWithToken(token: 'a.b.c', slug: 's'), isTrue);
      expect(c.roleSupported.value, isFalse);
      expect(api.meCalls, 0);
    });

    test('a failed profile load after a valid token removes the stored token', () async {
      api.me = null;
      api.meError = ApiException("Couldn't reach Eldermin.");
      final c = make();
      c.status.value = AuthStatus.unauthenticated;
      expect(await c.signInWithToken(token: 'a.b.c', slug: 's'), isFalse);
      expect(tokens.token, isNull);
      expect(c.loginNotice.value, isNotNull);
    });
  });

  group('profile refresh (owner decision B)', () {
    Future<AuthController> signedIn({bool classTeacher = false}) async {
      api.me = _staffMe(classTeacher: classTeacher);
      final c = make(token: 'stored');
      await c.bootstrap();
      api.meCalls = 0;
      return c;
    }

    test('resume refresh is throttled to once per 10 minutes (injected clock)', () async {
      final c = await signedIn();
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(api.meCalls, 0, reason: 'profile was just loaded');

      now = now.add(const Duration(minutes: 9, seconds: 59));
      await c.refreshProfile();
      expect(api.meCalls, 0);

      now = now.add(const Duration(seconds: 2)); // 10 min 1 s since last sync
      await c.refreshProfile();
      expect(api.meCalls, 1);

      now = now.add(const Duration(minutes: 5));
      await c.refreshProfile();
      expect(api.meCalls, 1, reason: 'window restarts after each sync');

      now = now.add(const Duration(minutes: 6));
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(api.meCalls, 2);
    });

    test('non-resume lifecycle states do not refresh', () async {
      final c = await signedIn();
      now = now.add(const Duration(hours: 1));
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(api.meCalls, 0);
    });

    test('force (pull-to-refresh) bypasses the throttle', () async {
      final c = await signedIn();
      await c.refreshProfile(force: true);
      await c.refreshProfile(force: true);
      expect(api.meCalls, 2);
    });

    test('class-teacher change propagates reactively with no re-login', () async {
      final c = await signedIn(classTeacher: false);
      final seen = <bool>[];
      final worker = ever(c.staffMe, (_) => seen.add(c.isClassTeacher));
      expect(c.isClassTeacher, isFalse);

      api.me = _staffMe(classTeacher: true); // admin made her a class teacher
      await c.refreshProfile(force: true);
      expect(c.isClassTeacher, isTrue);
      expect(seen, [true]);
      expect(c.status.value, AuthStatus.authenticated);
      expect(tokens.token, 'stored');

      api.me = _staffMe(classTeacher: false); // and removed again
      await c.refreshProfile(force: true);
      expect(c.isClassTeacher, isFalse);
      expect(seen, [true, false]);
      worker.dispose();
    });

    test('an unchanged profile does not re-emit', () async {
      final c = await signedIn();
      var emissions = 0;
      final worker = ever(c.staffMe, (_) => emissions++);
      await c.refreshProfile(force: true);
      expect(emissions, 0);
      worker.dispose();
    });

    test('a failed refresh keeps the last good profile and the session', () async {
      final c = await signedIn(classTeacher: true);
      api.meError = ApiException('No internet connection.');
      await c.refreshProfile(force: true);
      expect(c.isClassTeacher, isTrue);
      expect(c.status.value, AuthStatus.authenticated);
      expect(c.profileError.value, isNull);
    });

    test('does nothing when signed out or for unsupported roles', () async {
      final c = make();
      c.status.value = AuthStatus.unauthenticated;
      await c.refreshProfile(force: true);
      expect(api.meCalls, 0);
    });
  });
}
