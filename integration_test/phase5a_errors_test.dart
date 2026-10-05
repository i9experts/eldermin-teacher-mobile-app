// Phase 5a follow-up walkthrough: 403 states on screen and the timetable NOW/NEXT highlight, against the LOCAL STUB.
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase5a_errors_test.dart
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));
Future<void> shot(WidgetTester t, String name) async {
  print('SHOT:$name');
  await t.pump(const Duration(milliseconds: 2200));
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

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));
String sid(int i) => '64f${(0x200 + i).toRadixString(16).padLeft(21, '0')}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 5a 403 states + timetable highlight', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'classteacher@stub.test');
    await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await waitFor(t, navLabel('Attendance'));
    await settle(t, 2500);

    // Students list answers 403
    await stub(t, '/__stub/mode?feature=students&value=403');
    await t.tap(navLabel('Classes'));
    await settle(t, 800);
    await t.tap(find.byKey(const ValueKey('module_students')));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await settle(t, 800);
    await shot(t, '5a_60_students_403');
    await stub(t, '/__stub/mode?feature=students&value=ok');
    await t.pageBack();
    await settle(t, 600);

    // Attendance save answers 403, marks kept
    await t.tap(navLabel('Attendance'));
    await waitFor(t, find.byKey(const Key('hub_mark_button')));
    await t.tap(find.byKey(const Key('hub_mark_button')));
    await waitFor(t, find.byKey(const Key('mark_remaining_present')));
    await settle(t, 1500);
    await t.tap(find.byKey(const Key('mark_remaining_present')));
    await settle(t, 600);
    await stub(t, '/__stub/mode?feature=attbulk&value=403');
    await t.tap(find.byKey(const Key('submit_button')));
    await waitFor(t, find.byKey(const Key('attendance_confirm_dialog')));
    await t.tap(find.byKey(const Key('attendance_confirm_submit')));
    await waitFor(t, find.byKey(const Key('submit_retry')));
    await t.drag(find.byType(Scrollable).last, const Offset(0, 3000));
    await settle(t, 800);
    await shot(t, '5a_27_mark_error_403');
    await stub(t, '/__stub/mode?feature=attbulk&value=ok');
    await t.pageBack();
    await settle(t, 600);
    if (find.byKey(const Key('discard_confirm')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('discard_confirm')));
      await settle(t, 800);
    }

    // Timetable: scroll to the live NOW / NEXT periods
    await t.tap(navLabel('More'));
    await settle(t, 800);
    await t.tap(find.text('Timetable'));
    await waitFor(t, find.text('Day'));
    await settle(t, 2500);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await settle(t, 800);
    await shot(t, '5a_43_timetable_now_next');
  });
}
