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
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
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

/// Signs out through the real UI: More tab -> "Sign out" tile -> confirm
/// dialog -> "Sign out". [shotName] captures the confirmation dialog.
Future<void> signOutViaUi(WidgetTester t, {String? shotName}) async {
  await t.tap(find.text('More'));
  await waitFor(t, find.byType(MoreScreen));
  await settle(t, 500);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200,
      scrollable: find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable)));
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.text('Sign out of Eldermin Teacher?'));
  if (shotName != null) await shot(t, shotName, ms: 1200);
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 3 walkthrough against the stub', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, '00_splash', ms: 600);

    // ── Intro (first launch) ──
    await waitFor(t, find.text('Skip'));
    await shot(t, '01_intro_1');
    await t.tap(find.text('Next'));
    await settle(t, 700);
    await shot(t, '01_intro_2');
    await t.tap(find.text('Next'));
    await settle(t, 700);
    await shot(t, '01_intro_3');
    await t.tap(find.text('Get started'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await shot(t, '02_login');

    // ── Login validation + errors ──
    await t.tap(find.text('Sign in'));
    await settle(t, 500);
    await shot(t, '03_login_validation');
    await signIn(t, 'teacher@stub.test', 'WrongPass1');
    await waitFor(t, find.text('Invalid credentials'));
    await shot(t, '04_login_error_invalid_credentials');

    // ── School code expanded ──
    await t.tap(find.byKey(const Key('school_code_toggle')));
    await settle(t, 600);
    await shot(t, '05_login_school_code_expanded');

    // ── Forgot password ──
    await t.tap(find.text('Forgot password?'));
    await waitFor(t, find.text('Send reset link'));
    await settle(t);
    await t.enterText(tf('Email'), 'anyone@stub.test');
    await shot(t, '06_forgot_password_form', ms: 800);
    await t.tap(find.text('Send reset link'));
    await waitFor(t, find.text('Check your email'));
    await shot(t, '07_forgot_password_success');

    // ── Reset password via the manual "paste" fallback ──
    await t.tap(find.text('I have a reset code or link'));
    await waitFor(t, tf('Paste reset code or link'));
    await settle(t);
    await shot(t, '08_reset_password_paste', ms: 1200);
    await t.enterText(tf('Paste reset code or link'), 'https://app.eldermin.com/reset-password?token=$_resetToken');
    await t.tap(find.text('Continue'));
    await waitFor(t, tf('New password'));
    await shot(t, '09_reset_password_form_from_paste', ms: 1500);

    // back to login (pop reset + forgot)
    Get.until((r) => r.isFirst);
    await waitFor(t, find.text('Sign in'));
    await settle(t);

    // ── Sign in as a plain teacher ──
    await signIn(t, 'teacher@stub.test', 'StubPass123');
    await waitFor(t, find.text('Timetable'));
    await settle(t, 1500);
    await shot(t, '10_home_plain_teacher_timetable_tab');

    // Admin makes her a class teacher; pull-to-refresh on Home picks it up, no re-login.
    print('STUB:/__stub/class-teacher?email=teacher@stub.test&value=true');
    await t.pump(const Duration(seconds: 2));
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 420));
    await t.pump(const Duration(milliseconds: 150));
    await shot(t, '11_home_pull_to_refresh_in_progress', ms: 300);
    await waitFor(t, find.text('Attendance'));
    await shot(t, '12_home_after_pull_attendance_tab_no_relogin');
    print('STUB:/__stub/class-teacher?email=teacher@stub.test&value=false');
    await t.pump(const Duration(seconds: 1));

    await signOutViaUi(t, shotName: '21_sign_out_confirmation_dialog');

    // ── Class teacher login ──
    await signIn(t, 'classteacher@stub.test', 'StubPass123');
    await waitFor(t, find.text('Attendance'));
    await settle(t, 1500);
    await shot(t, '13_home_class_teacher_attendance_tab');
    await signOutViaUi(t);

    // ── Unsupported role ──
    await signIn(t, 'principal@stub.test', 'StubPass123');
    await waitFor(t, find.text('Please use the Eldermin web portal'));
    await settle(t);
    await shot(t, '14_unsupported_role');
    await t.tap(find.text('Sign out'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);

    // ── Reset via real deep link (warm start) ──
    await openLink(t, 'eldermin-teacher://reset-password?token=$_resetToken');
    await waitFor(t, tf('New password'), seconds: 30);
    await settle(t, 800);
    await t.enterText(tf('New password'), 'NewPass123');
    await t.enterText(tf('Confirm new password'), 'NewPass123');
    await shot(t, '15_reset_password_via_deeplink', ms: 900);
    await t.tap(find.text('Update password'));
    await settle(t, 700);
    await shot(t, '16_reset_success_toast_back_on_login', ms: 400);
    await waitFor(t, find.text('Sign in'));
    await settle(t, 3000);

    // Same (now used) token again -> invalid/expired message, inline.
    await openLink(t, 'eldermin-teacher://reset-password?token=$_resetToken');
    await waitFor(t, tf('New password'), seconds: 30);
    await t.enterText(tf('New password'), 'NewPass123');
    await t.enterText(tf('Confirm new password'), 'NewPass123');
    await t.tap(find.text('Update password'));
    await waitFor(t, find.text('This reset link is invalid or has expired'));
    await shot(t, '17_reset_invalid_or_expired_token');
    Get.until((r) => r.isFirst);
    await waitFor(t, find.text('Sign in'));
    await settle(t);

    // ── Token + slug auto-login via deep link ──
    await openLink(t, 'eldermin-teacher://login?token=stub.classteacher.dummy&slug=demo-school');
    await waitFor(t, find.text('Attendance'), seconds: 30);
    await settle(t, 1500);
    await shot(t, '18_token_login_deeplink_home_class_teacher');

    // A token link while signed in -> confirmation (never a silent switch). Cancel keeps the session.
    await openLink(t, 'eldermin-teacher://login?token=stub.teacher.dummy&slug=demo-school');
    await waitFor(t, find.text('Switch account?'));
    await shot(t, '22_deeplink_switch_account_dialog', ms: 1200);
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await settle(t, 800);
    expect(find.text('Attendance'), findsWidgets, reason: 'Cancel keeps the signed-in session');
    await signOutViaUi(t);

    // Rejected token -> clear error, Login.
    await openLink(t, 'eldermin-teacher://login?token=stub.expired.dummy&slug=demo-school');
    await waitFor(t, find.textContaining('invalid or has expired'), seconds: 30);
    await settle(t, 800);
    await shot(t, '19_token_login_rejected_falls_back_to_login');
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
