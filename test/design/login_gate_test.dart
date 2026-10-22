import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/login_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/unsupported_role_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/login_result.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

class _NoLinks extends DeepLinkService {
  _NoLinks(AuthController auth) : super(auth: auth);
  @override
  Future<void> init() async {}
}

/// A sign-in that succeeds as a role the app does not support: the gate then shows
/// [UnsupportedRoleScreen], which needs no other services.
class _Api extends AuthApiService {
  _Api() : super(BaseClient());
  @override
  Future<LoginResult> login({required String email, required String password, String? slug}) async =>
      LoginResult(accessToken: 'a.b.c', user: TeacherUser(id: 'u', name: 'T', email: email, role: 'parent'), institution: const Institution(slug: 's'));
  @override
  Future<AuthMe> fetchAuthMe({String? token}) async => const AuthMe(id: 'u', name: 'T', email: 'a@s.test', role: 'parent');
  @override
  Future<void> logout() async {}
}

void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  Future<void> mount(WidgetTester t, {bool reduce = false}) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    final api = _Api();
    Get.put<AuthApiService>(api);
    final auth = Get.put<AuthController>(AuthController(
      api: api,
      permissions: PermissionService(),
      tokenStore: MemTokens(),
      minSplash: Duration.zero,
      resetScopedControllers: () async {},
      notify: (_) {},
    ));
    Get.put<DeepLinkService>(_NoLinks(auth));
    Get.lazyPut(() => LoginController(), fenix: true);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 50));
    auth
      ..introSeen.value = true
      ..status.value = AuthStatus.unauthenticated;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: c!),
      home: const AuthGate(),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1200));
  }

  Future<void> signIn(WidgetTester t) async {
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'tess@stub.test');
    await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
    await t.tap(find.byType(EmMorphButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
  }

  testWidgets('success: the login screen stays up with the check, then the gate moves on', (t) async {
    await mount(t);
    await signIn(t);
    expect(find.byType(UnsupportedRoleScreen), findsNothing, reason: 'held');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(t.widget<EmMorphButton>(find.byType(EmMorphButton)).phase, EmMorphPhase.success);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginScreen), findsOneWidget, reason: 'still showing the check');
    await t.pump(const Duration(milliseconds: 400)); // past the 700 ms hold
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(UnsupportedRoleScreen), findsOneWidget);
  });

  testWidgets('reduce motion: a short hold only (crossfade length)', (t) async {
    await mount(t, reduce: true);
    await signIn(t);
    expect(find.byType(LoginScreen), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(UnsupportedRoleScreen), findsOneWidget);
  });

  testWidgets('under the splash overlay the entrance waits; it plays as the navy lifts', (t) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    final api = _Api();
    Get.put<AuthApiService>(api);
    final auth = Get.put<AuthController>(
        AuthController(api: api, permissions: PermissionService(), tokenStore: MemTokens(), minSplash: Duration.zero, resetScopedControllers: () async {}, notify: (_) {})
          ..status.value = AuthStatus.unauthenticated);
    auth.introSeen.value = true;
    Get.lazyPut(() => LoginController(), fenix: true);
    EmLogoHandoff.splashShowing = true;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const LoginScreen()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    double opacity() => t.widget<FadeTransition>(find.ancestor(of: find.widgetWithText(TextFormField, 'Email'), matching: find.byType(FadeTransition)).first).opacity.value;
    expect(opacity(), 0, reason: 'nothing plays while the splash covers the screen');
    EmLogoHandoff.flying.value = true; // the splash starts its exit
    await t.pump();
    await t.pump(const Duration(milliseconds: 1200));
    expect(opacity(), 1);
    EmLogoHandoff.flying.value = false;
  });
}
