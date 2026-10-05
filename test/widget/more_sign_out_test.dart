import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/controllers/more_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements TokenStore {
  String? token = 'tok';
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async => token = null;
}

class _Api extends AuthApiService {
  _Api() : super(BaseClient());
  int logoutCalls = 0;
  @override
  Future<AuthMe> fetchAuthMe({String? token}) async =>
      const AuthMe(id: 'u', name: 'T', email: 't@s.test', role: 'teacher');
  @override
  Future<StaffMe> fetchStaffMe() async => StaffMe.fromJson({
        'user': {'id': 'u', 'name': 'T', 'email': 't@s.test', 'role': 'teacher'},
        'staffId': 's1',
        'teacherProfile': {'isClassTeacher': false},
        'institution': {'slug': 's'},
      });
  @override
  Future<void> logout() async => logoutCalls++;
}

void main() {
  late _Api api;
  late _Tokens tokens;
  late AuthController auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    api = _Api();
    tokens = _Tokens();
    final perms = PermissionService();
    auth = AuthController(
      api: api,
      permissions: perms,
      tokenStore: tokens,
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
      notify: (_) {},
    );
    Get.put<PermissionService>(perms);
    Get.put<AuthController>(auth);
    Get.put(MoreController());
  });
  tearDown(Get.reset);

  Future<void> pumpMore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: MoreScreen())));
    await tester.pump();
    expect(auth.status.value, AuthStatus.authenticated);
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('more_sign_out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Eldermin Teacher?'), findsOneWidget);
  }

  testWidgets('Cancel keeps the session', (tester) async {
    await pumpMore(tester);
    await openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(auth.status.value, AuthStatus.authenticated);
    expect(tokens.token, 'tok');
    expect(api.logoutCalls, 0);
  });

  testWidgets('Sign out confirms, then calls AuthController.logout', (tester) async {
    await pumpMore(tester);
    await openDialog(tester);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(auth.status.value, AuthStatus.unauthenticated);
    expect(tokens.token, isNull);
    expect(api.logoutCalls, 1);
  });
}
