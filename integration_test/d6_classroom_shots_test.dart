// D6 walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data): every restyled classroom screen at text scale 1.0 and 1.3.
// Prints SHOT:<name>/STUB:<path> markers for tool/dev/capture_walkthrough.sh.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d6_classroom_shots_test.dart
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 1500}) async {
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

Finder withKeyPrefix(String prefix) => find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix));

Future<void> back(WidgetTester t) async {
  await t.pageBack(); // finds the app bar's circle by its "Back" tooltip
  await settle(t, 900);
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 4000));
  await settle(t, 300);
}

Future<void> openClasses(WidgetTester t, String id) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1200);
  final tile = find.byKey(ValueKey('module_$id'));
  await t.scrollUntilVisible(tile, 250, scrollable: find.byType(Scrollable).last);
  await settle(t, 300);
  await t.tap(tile);
  await settle(t, 2600);
}

Future<void> openMore(WidgetTester t, String title) async {
  await t.tap(navLabel('More'));
  await settle(t, 1200);
  await t.scrollUntilVisible(find.text(title), 250, scrollable: find.byType(Scrollable).last);
  await settle(t, 300);
  await t.tap(find.text(title));
  await settle(t, 2600);
}

Future<void> homeTab(WidgetTester t) async {
  await t.tap(navLabel('Home'));
  await settle(t, 800);
}

Future<void> screens(WidgetTester t, String sc) async {
  // attendance hub -> mark -> history
  await openClasses(t, 'attendance');
  await shot(t, 'd6_attendance_hub_$sc');
  await t.tap(find.byKey(const Key('hub_mark_button')));
  await settle(t, 2600);
  await shot(t, 'd6_attendance_mark_$sc');
  await t.tap(find.byKey(const Key('mark_remaining_present')));
  await settle(t, 800);
  await shot(t, 'd6_attendance_mark_marked_$sc');
  await back(t);
  if (find.byKey(const Key('discard_confirm')).evaluate().isNotEmpty) {
    await t.tap(find.byKey(const Key('discard_confirm')));
    await settle(t, 900);
  }
  await t.tap(find.byKey(const Key('hub_history_button')));
  await settle(t, 2600);
  await shot(t, 'd6_attendance_history_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // students -> Student 360
  await openClasses(t, 'students');
  await shot(t, 'd6_students_$sc');
  await t.tap(withKeyPrefix('student_').first);
  await settle(t, 2600);
  await shot(t, 'd6_student360_$sc');
  await t.drag(find.byType(Scrollable).last, const Offset(0, -700));
  await settle(t, 500);
  await shot(t, 'd6_student360_lower_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // homework list -> detail -> form -> date picker
  await openClasses(t, 'homework');
  await shot(t, 'd6_homework_list_$sc');
  await t.tap(find.byWidgetPredicate((w) => w.key is ValueKey && RegExp(r'^hw_[0-9a-f]{8,}').hasMatch('${(w.key as ValueKey).value}')).first);
  await settle(t, 2600);
  await shot(t, 'd6_homework_detail_$sc');
  await back(t);
  await t.tap(find.byKey(const Key('hw_new_fab')));
  await settle(t, 2600);
  await shot(t, 'd6_homework_form_$sc');
  await t.scrollUntilVisible(find.byKey(const Key('hw_due_picker')), 250, scrollable: find.byType(Scrollable).last);
  await settle(t, 300);
  await t.tap(find.byKey(const Key('hw_due_picker')));
  await settle(t, 1500);
  await shot(t, 'd6_date_picker_$sc');
  await t.tapAt(const Offset(200, 60)); // barrier
  await settle(t, 800);
  await back(t);
  await back(t);
  await homeTab(t);

  // behaviour list -> log form
  await openClasses(t, 'behaviour');
  await shot(t, 'd6_behaviour_list_$sc');
  await t.tap(find.byKey(const Key('beh_new_fab')));
  await settle(t, 2600);
  await shot(t, 'd6_behaviour_form_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // timetable day / week
  await openMore(t, 'Timetable');
  await shot(t, 'd6_timetable_day_$sc');
  await t.tap(find.text('Week'));
  await settle(t, 900);
  await shot(t, 'd6_timetable_week_$sc');
  await back(t);
  await homeTab(t);

  // student leave requests -> detail -> review sheet
  await openMore(t, 'Student leave requests');
  await shot(t, 'd6_student_leaves_$sc');
  await t.tap(withKeyPrefix('leave_').first);
  await settle(t, 2600);
  await shot(t, 'd6_student_leave_detail_$sc');
  await t.tap(find.byKey(const Key('leave_approve')));
  await settle(t, 1500);
  await shot(t, 'd6_leave_review_sheet_$sc');
  await t.tap(find.byKey(const Key('review_cancel')));
  await settle(t, 800);
  await back(t);
  await back(t);
  await homeTab(t);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D6 classroom walkthrough', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await signIn(t, 'classteacher@stub.test');
    await waitFor(t, find.byKey(const Key('app_shell_nav')));
    await settle(t, 4000);
    await screens(t, 'normal');
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1200);
    await screens(t, 'scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
