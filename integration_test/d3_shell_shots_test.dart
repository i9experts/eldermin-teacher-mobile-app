// D3 shell + Home walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data):
// Home (1.0x and 1.3x), the Quick actions sheet for a class teacher and a subject teacher,
// and every tab. Prints SHOT:<name>/STUB:<path> markers for tool/dev/capture_walkthrough.sh.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d3_shell_shots_test.dart
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2000}) async {
  print('SHOT:$name');
  await t.pump(Duration(milliseconds: ms));
}

Future<void> stub(WidgetTester t, String path) async {
  print('STUB:$path');
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder navLabel(String label) => find.descendant(of: find.byKey(const Key('app_shell_nav')), matching: find.text(label));
Finder tf(String hint) => find.widgetWithText(TextFormField, hint);

Future<void> signIn(WidgetTester t, String email) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), 'StubPass123');
  await t.tap(find.text('Sign in'));
  await settle(t, 800);
}

Future<void> signOutViaUi(WidgetTester t) async {
  await t.tap(navLabel('More'));
  await waitFor(t, find.byType(MoreScreen));
  await settle(t, 500);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200,
      scrollable: find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable)));
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.text('Sign out of Eldermin Teacher?'));
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

Future<void> openSheet(WidgetTester t, String name) async {
  await t.tap(find.byKey(const Key('quick_actions_fab')));
  await settle(t, 900);
  await shot(t, name);
  await t.tapAt(const Offset(10, 60));
  await settle(t, 700);
}

Future<void> scrollHome(WidgetTester t, double dy) async {
  await t.drag(find.byType(SingleChildScrollView).first, Offset(0, -dy));
  await settle(t, 600);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D3 shell walkthrough', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');

    // ── Class teacher ──
    await signIn(t, 'classteacher@stub.test');
    await waitFor(t, find.byKey(const Key('app_shell_nav')));
    await waitFor(t, find.byKey(const Key('mark_attendance_button')));
    await settle(t, 3500);
    await shot(t, 'd3_01_home_class_teacher_top');
    await scrollHome(t, 600);
    await shot(t, 'd3_02_home_class_teacher_middle');
    await scrollHome(t, 1200);
    await shot(t, 'd3_03_home_class_teacher_bottom');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 4000));
    await settle(t, 600);
    await openSheet(t, 'd3_04_quick_actions_class_teacher');
    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, 'd3_05_tab_classes');
    await t.tap(navLabel('Messages'));
    await settle(t, 2000);
    await shot(t, 'd3_06_tab_messages');
    await t.tap(navLabel('More'));
    await settle(t, 1500);
    await shot(t, 'd3_07_tab_more');
    await t.tap(navLabel('Home'));
    await settle(t, 1200);

    // text scale 1.3
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1500);
    await shot(t, 'd3_08_home_class_teacher_scale13_top');
    await scrollHome(t, 600);
    await shot(t, 'd3_09_home_class_teacher_scale13_middle');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 4000));
    await settle(t, 600);
    await openSheet(t, 'd3_10_quick_actions_scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    await settle(t, 800);
    await signOutViaUi(t);

    // ── Subject teacher (no class) ──
    await stub(t, '/__stub/reset-state');
    await signIn(t, 'teacher@stub.test');
    await waitFor(t, find.byKey(const Key('app_shell_nav')));
    await settle(t, 4000);
    await shot(t, 'd3_11_home_subject_teacher_top');
    await openSheet(t, 'd3_12_quick_actions_subject_teacher');
    await signOutViaUi(t);
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
