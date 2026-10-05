// Phase 3 on-device walkthrough, driven against the LOCAL STUB SERVER only
// (tool/dev/stub_server.py, dummy data). It is not a unit test: it prints
// markers that an external script reacts to (screenshots, `simctl openurl`,
// stub control calls):
//   SHOT:<name>      -> take a screenshot now
//   STUB:<path>      -> POST to the stub (e.g. /__stub/class-teacher?...)
// Run via the orchestration described in the README ("Phase 3 walkthrough").
//
//   flutter test integration_test/phase3_demo_test.dart -d <simulator-id> \
//     --dart-define=API_BASE_URL=http://localhost:3999
import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

const _resetToken = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// iOS shows a system "Open in <app>?" prompt for custom-scheme links from
/// `simctl openurl` that cannot be tapped without Accessibility access, so
/// the link is injected into the same Dart entry point app_links feeds
/// (DeepLinkService.handleUri) - the native hand-off itself is not exercised.
Future<void> openLink(WidgetTester t, String url) async {
  Get.find<DeepLinkService>().handleUri(Uri.parse(url));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2600}) async {
  print('SHOT:$name');
  await t.pump(Duration(milliseconds: ms));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder tf(String hint) => find.widgetWithText(TextFormField, hint);

Future<void> signIn(WidgetTester t, String email, String password) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), password);
  await t.tap(find.text('Sign in'));
  await settle(t, 800);
}

Future<void> signOutViaController(WidgetTester t) async {
  Get.find<AuthController>().logout();
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Reset form opened by a link, held still for a clean screenshot', (t) async {
    app.main();
    await waitFor(t, find.text('Skip'));
    await t.tap(find.byKey(const Key('intro_skip')));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await openLink(t, 'eldermin-teacher://reset-password?token=$_resetToken');
    await waitFor(t, tf('New password'), seconds: 30);
    await settle(t, 1500);
    await shot(t, '15_reset_password_via_deeplink', ms: 5000);
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
