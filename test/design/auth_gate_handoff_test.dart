import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/login_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/login_controller.dart';
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

class _NoLinks extends DeepLinkService {
  _NoLinks(AuthController auth) : super(auth: auth);
  @override
  Future<void> init() async {}
}

/// The real `AuthGate`: splash overlay -> hand-off -> destination.
void main() {
  setUpAll(loadDesignFonts);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  Future<AuthController> mount(WidgetTester t, {required AuthStatus start}) async {
    final auth = setUpAuthDeps();
    // let the controller's own bootstrap (started by Get.put) finish, then take over the state
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // prefs
    await t.pump(const Duration(milliseconds: 50)); // minSplash timer (fake time)
    auth
      ..introSeen.value = true
      ..status.value = start;
    Get.put<DeepLinkService>(_NoLinks(auth));
    Get.lazyPut(() => LoginController(), fenix: true);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const AuthGate()));
    return auth;
  }

  testWidgets('already resolved at start: no splash overlay at all', (t) async {
    await mount(t, start: AuthStatus.unauthenticated);
    await t.pump();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('unknown -> unauthenticated: splash stays on top until the logo has landed on the login logo', (t) async {
    final auth = await mount(t, start: AuthStatus.unknown);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    auth.introSeen.value = true;
    auth.status.value = AuthStatus.unauthenticated;
    await t.pump();
    expect(find.byType(LoginScreen), findsOneWidget, reason: 'built under the overlay');
    expect(find.byType(SplashScreen), findsOneWidget);

    await t.pump(const Duration(milliseconds: 500)); // end of beat 1 (700 ms)
    await t.pump(const Duration(milliseconds: 300));
    expect(EmLogoHandoff.flying.value, isTrue);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(SplashScreen), findsNothing);
    expect(EmLogoHandoff.flying.value, isFalse);
    expect(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(Opacity)), findsNothing);
    expect(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark)), findsOneWidget);
  });
}
