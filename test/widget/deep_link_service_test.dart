import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/reset_password/views/reset_password_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hex = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln';

class _Tokens implements TokenStore {
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async => token = null;
}

class _Api extends AuthApiService {
  _Api() : super(BaseClient());
  final authMeTokens = <String?>[];
  bool reject = false;
  @override
  Future<AuthMe> fetchAuthMe({String? token}) async {
    authMeTokens.add(token);
    if (reject) throw ApiException('Unauthorized', statusCode: 401);
    return const AuthMe(id: 'u', name: 'T', email: 't@s.test', role: 'teacher');
  }

  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {'id': 'u', 'name': 'T', 'email': 't@s.test', 'role': 'teacher'},
        'staffId': 's1',
        'teacherProfile': {'isClassTeacher': false},
        'institution': {'slug': 's'},
      });
  @override
  Future<void> logout() async {}
}

void main() {
  late _Api api;
  late _Tokens tokens;
  late AuthController auth;
  late DeepLinkService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    api = _Api();
    tokens = _Tokens();
    auth = AuthController(
      api: api,
      permissions: PermissionService(),
      tokenStore: tokens,
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
      notify: (_) {},
    )..status.value = AuthStatus.unauthenticated;
    Get.put<AuthApiService>(api);
    Get.put<AuthController>(auth);
    svc = Get.put<DeepLinkService>(DeepLinkService(auth: auth));
    // Let AuthController's own onInit bootstrap (no stored token) finish first.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    auth.status.value = AuthStatus.unauthenticated;
  });
  tearDown(Get.reset);

  testWidgets('warm-start reset link opens the reset screen with the token already applied', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Text('root')),
      getPages: [GetPage(name: Routes.resetPassword, page: () => const ResetPasswordScreen())],
    ));
    svc.handleUri(Uri.parse('eldermin-teacher://reset-password?token=$_hex'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'New password'), findsOneWidget);
    expect(svc.resetToken.value, isNull, reason: 'token cleared from deep-link state after use');
  });

  testWidgets('invalid / hostile links are ignored entirely', (tester) async {
    for (final u in [
      'javascript:alert(1)',
      'eldermin-teacher://reset-password',
      'https://evil.com/reset-password?token=$_hex',
      'eldermin-teacher://login?token=x&slug=y',
    ]) {
      svc.handleUri(Uri.parse(u));
    }
    await tester.pump();
    expect(svc.resetToken.value, isNull);
    expect(api.authMeTokens, isEmpty);
    expect(tokens.token, isNull);
  });

  testWidgets('token link signs in (validated via /auth/me first)', (tester) async {
    await tester.runAsync(() async {
      svc.handleUri(Uri.parse('eldermin-teacher://login?token=$_jwt&slug=demo-school'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(api.authMeTokens, [_jwt]);
    expect(auth.status.value, AuthStatus.authenticated);
    expect(tokens.token, _jwt);
  });

  testWidgets('token link with a rejected token falls back to login with an error', (tester) async {
    api.reject = true;
    await tester.runAsync(() async {
      svc.handleUri(Uri.parse('eldermin-teacher://login?token=$_jwt&slug=demo-school'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(auth.status.value, AuthStatus.unauthenticated);
    expect(tokens.token, isNull);
    expect(auth.loginNotice.value, isNotNull);
  });

  testWidgets('cold start: a link received while status is unknown waits for the session check', (tester) async {
    auth.status.value = AuthStatus.unknown;
    await tester.runAsync(() async {
      svc.handleUri(Uri.parse('eldermin-teacher://login?token=$_jwt&slug=demo-school'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.authMeTokens, isEmpty, reason: 'must not act before bootstrap resolves');
      auth.status.value = AuthStatus.unauthenticated;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(api.authMeTokens, [_jwt]);
    expect(auth.status.value, AuthStatus.authenticated);
  });

  testWidgets('a token link never replaces an active session', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: Text('root'))));
    auth.status.value = AuthStatus.authenticated;
    tokens.token = 'existing';
    svc.handleUri(Uri.parse('eldermin-teacher://login?token=$_jwt&slug=demo-school'));
    await tester.pump();
    expect(api.authMeTokens, isEmpty);
    expect(tokens.token, 'existing');
    await tester.pump(const Duration(seconds: 3)); // let the toast timer finish
  });
}
