// D1a re-palette walkthrough against the LOCAL STUB (tool/dev/stub_server.py,
// dummy data): Login, Home, Attendance, Messages, More. Prints SHOT:<name>
// markers for tool/dev/capture_walkthrough.sh. Not a unit test.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d1a_repalette_shots_test.dart
import 'package:get/get.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

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
Finder navLabel(String label) => find.descendant(of: find.byKey(const Key('app_shell_nav')), matching: find.text(label));

/// The Attendance hub is no longer a bottom tab: Classes tab -> Attendance card (a pushed page; go back once more to reach the shell).
Future<void> openAttendanceHub(WidgetTester t) async {
  // the bar is hidden while a pushed page covers the shell: go back to it first
  for (var i = 0; i < 6 && (Get.key.currentState?.canPop() ?? false); i++) {
    await t.pageBack();
    await t.pump(const Duration(milliseconds: 700));
    // an unsaved-changes screen asks before it closes
    if (find.byKey(const Key('discard_confirm')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('discard_confirm')));
      await t.pump(const Duration(milliseconds: 700));
    }
  }
  await t.tap(navLabel('Classes'));
  await t.pump(const Duration(milliseconds: 800));
  await t.tap(find.byKey(const ValueKey('module_attendance')));
  await t.pump(const Duration(milliseconds: 800));
}

/// Timetable is no longer a bottom tab: centre FAB -> Timetable (a pushed page).
Future<void> openTimetableViaFab(WidgetTester t) async {
  await t.tap(find.byKey(const Key('quick_actions_fab')));
  await t.pump(const Duration(milliseconds: 700));
  await t.tap(find.byKey(const Key('quick_action_timetable')));
  await t.pump(const Duration(milliseconds: 900));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D1a re-palette screens', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await shot(t, 'd1a_01_intro');
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await shot(t, 'd1a_02_login');

    await t.enterText(tf('Email'), 'classteacher@stub.test');
    await t.enterText(tf('Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await settle(t, 800);
    await waitFor(t, find.text('Mark Attendance'));
    await settle(t, 4000);
    await shot(t, 'd1a_03_home');

    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, 'd1a_04_classes');

    await t.tap(find.byKey(const Key('quick_actions_fab')));
    await settle(t, 1500);
    await shot(t, 'd1a_05_quick_actions');
    await t.tapAt(const Offset(10, 10));
    await settle(t, 800);

    await t.tap(navLabel('Messages'));
    await settle(t, 2500);
    await shot(t, 'd1a_06_messages');

    await t.tap(navLabel('More'));
    await settle(t, 1500);
    await shot(t, 'd1a_07_more');
  });
}
