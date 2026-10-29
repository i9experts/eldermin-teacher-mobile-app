// A1 item 6: a suspended school gets a clean full-screen state with the server's message and only "Log out".
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/school_suspended_screen.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;

void main() {
  setUpAll(loadDesignFonts);
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  const serverText = "Your school's account is currently suspended. Please contact your school administration.";

  testWidgets('shows the server message, no retry / navigation, and Log out ends the session', (t) async {
    final h = (await t.runAsync(() => signedIn()))!;
    h.auth.handleSchoolSuspended(serverText);
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const SchoolSuspendedScreen()));
    await t.pump();
    expect(find.text(serverText), findsOneWidget);
    expect(find.byKey(const Key('school_suspended')), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    for (final other in ['Try again', 'Retry', 'Home', 'Classes']) {
      expect(find.text(other), findsNothing, reason: other);
    }
    await t.tap(find.byKey(const Key('school_suspended_logout')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(h.auth.status.value, AuthStatus.unauthenticated);
    expect(h.auth.schoolSuspendedMessage.value, isNull);
  });

  testWidgets('fits 320 wide at text scale 1.3 without overflow', (t) async {
    final h = (await t.runAsync(() => signedIn()))!;
    h.auth.handleSchoolSuspended(serverText);
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
      child: GetMaterialApp(theme: AppTheme.light, home: const SchoolSuspendedScreen()),
    ));
    await t.pump();
    expect(tester0(t), isNull);
  });
}

Object? tester0(WidgetTester t) => t.takeException();
