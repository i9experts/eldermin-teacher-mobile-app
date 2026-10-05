import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

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
  int meCalls = 0;
  int logoutCalls = 0;

  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
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
  late _FakeApi api;
  late _MemoryTokenStore tokens;
  late PermissionService permissions;
  late int resets;

  AuthController make({String? token}) {
    tokens = _MemoryTokenStore(token);
    resets = 0;
    return AuthController(
      api: api,
      permissions: permissions,
      tokenStore: tokens,
      minSplash: Duration.zero,
      resetScopedControllers: () async => resets++,
    );
  }

  setUp(() {
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

  test('restores a stored session via GET /staff-portal/me', () async {
    api.me = _staffMe(classTeacher: true);
    final auth = make(token: 'stored');
    await auth.bootstrap();
    expect(auth.status.value, AuthStatus.authenticated);
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

  test('a 401 on restore ends the session (global hook -> logout), never stuck on splash', () async {
    final api401 = _Logout401Api();
    final c = AuthController(
      api: api401,
      permissions: PermissionService(),
      tokenStore: _MemoryTokenStore('stale'),
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
    );
    api401.onUnauthorized = c.logout; // what InitialBinding wires via DioService
    await c.bootstrap();
    expect(c.status.value, AuthStatus.unauthenticated);
  });
}

class _Logout401Api extends _FakeApi {
  void Function()? onUnauthorized;
  @override
  Future<StaffMe> fetchStaffMe() async {
    onUnauthorized?.call();
    throw ApiException('Unauthorized', statusCode: 401);
  }
}
