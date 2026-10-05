// Phase 5a on-device walkthrough (Timetable, Attendance, My students / Student 360, 403 state), driven against the LOCAL STUB
// (tool/dev/stub_server.py, dummy data). Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_walkthrough.sh.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase5a_classroom_test.dart
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2200}) async {
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

Finder tf(String hint) => find.widgetWithText(TextFormField, hint);

String sid(int i) => '64f${(0x200 + i).toRadixString(16).padLeft(21, '0')}';

Finder chip(int i, String wire) => find.byKey(ValueKey('chip_${sid(i)}_$wire'));

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(find.byType(Scrollable).last, Offset(0, -dy));
  await settle(t, 600);
}

Future<void> tapChip(WidgetTester t, int i, String wire) async {
  await t.ensureVisible(chip(i, wire));
  await t.tap(chip(i, wire));
  await t.pump(const Duration(milliseconds: 120));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 5a classroom walkthrough against the stub', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await t.enterText(tf('Email'), 'classteacher@stub.test');
    await t.enterText(tf('Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await waitFor(t, navLabel('Attendance'));
    await settle(t, 2500);

    // ── Attendance hub, then the mark screen ──
    await t.tap(navLabel('Attendance'));
    await waitFor(t, find.byKey(const Key('hub_mark_button')));
    await settle(t, 1500);
    await shot(t, '5a_20_attendance_hub_not_marked');
    await t.tap(find.byKey(const Key('hub_mark_button')));
    await waitFor(t, find.byKey(const Key('mark_bottom_bar')));
    await settle(t, 1500);
    await shot(t, '5a_21_mark_unmarked');

    // partially marked
    const wires = {2: 'absent', 4: 'late', 5: 'excused'};
    for (var i = 0; i < 6; i++) {
      await tapChip(t, i, wires[i] ?? 'present'); // rows are lazy: mark top-down, never revisit a scrolled-away row
    }
    await settle(t, 600);
    await shot(t, '5a_22_mark_partial');

    // submit while incomplete -> "N not marked" prompt
    await t.tap(find.byKey(const Key('submit_button')));
    await settle(t, 800);
    await shot(t, '5a_23_mark_not_marked_prompt');

    // complete + confirmation summary
    await t.tap(find.byKey(const Key('mark_remaining_present')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('submit_button')));
    await waitFor(t, find.byKey(const Key('attendance_confirm_dialog')));
    await settle(t, 800);
    await shot(t, '5a_24_mark_confirm_summary');

    // offline error keeps the marks; then retry
    await stub(t, '/__stub/mode?feature=attbulk&value=drop');
    await t.tap(find.byKey(const Key('attendance_confirm_submit')));
    await waitFor(t, find.byKey(const Key('submit_retry')));
    await settle(t, 800);
    await t.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await settle(t, 600);
    await shot(t, '5a_25_mark_error_marks_kept');
    await stub(t, '/__stub/mode?feature=attbulk&value=ok');
    await t.tap(find.byKey(const Key('submit_retry')));
    await waitFor(t, find.text('Saved'));
    await settle(t, 800);
    await shot(t, '5a_26_mark_saved');

    // ── History ──
    await t.pageBack();
    await settle(t, 800);
    await waitFor(t, find.byKey(const Key('hub_history_button')));
    await settle(t, 1000);
    await shot(t, '5a_28_attendance_hub_marked');
    await t.tap(find.byKey(const Key('hub_history_button')));
    await waitFor(t, find.byKey(const Key('history_calendar')));
    await settle(t, 2500);
    await shot(t, '5a_30_history_calendar');
    await scroll(t, 400);
    await shot(t, '5a_31_history_day_detail');

    // ── Timetable (class teachers reach it via More) ──
    await t.pageBack();
    await settle(t, 600);
    await t.tap(navLabel('More'));
    await settle(t, 800);
    await t.tap(find.text('Timetable'));
    await settle(t, 2500);
    await shot(t, '5a_40_timetable_day');
    await t.tap(find.text('Week'));
    await settle(t, 800);
    await shot(t, '5a_41_timetable_week');
    await scroll(t, 700);
    await shot(t, '5a_42_timetable_week_lower');
    await t.pageBack();
    await settle(t, 600);

    // ── Students + Student 360 ──
    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, '5a_50_classes_grid');
    await t.tap(find.byKey(const ValueKey('module_students')));
    await waitFor(t, find.byKey(const Key('students_count')));
    await settle(t, 1500);
    await shot(t, '5a_51_students_list');
    await t.tap(find.byKey(const ValueKey('class_chip_1')));
    await settle(t, 2200);
    await shot(t, '5a_52_students_second_class');
    await t.tap(find.byKey(const ValueKey('class_chip_0')));
    await settle(t, 1500);
    await t.tap(find.byKey(ValueKey('student_${sid(7)}')));
    await waitFor(t, find.byKey(const Key('student_profile')));
    await settle(t, 2500);
    await shot(t, '5a_53_student_360_top');
    await scroll(t, 600);
    await shot(t, '5a_54_student_360_middle');
    await scroll(t, 900);
    await shot(t, '5a_55_student_360_bottom');
    await t.pageBack();
    await settle(t, 600);

    // ── 403 state (students endpoint) ──
    await stub(t, '/__stub/mode?feature=students&value=403');
    await t.tap(find.byKey(const ValueKey('class_chip_1')));
    await settle(t, 600);
    await t.tap(find.byKey(const ValueKey('class_chip_0')));
    await settle(t, 800);
    await t.drag(find.byType(Scrollable).last, const Offset(0, 500));
    await settle(t, 2500);
    await shot(t, '5a_60_students_403');
    await stub(t, '/__stub/mode?feature=students&value=ok');

    // ── 403 from the server on save (reopen the mark screen from the hub) ──
    await t.tap(navLabel('Attendance'));
    await waitFor(t, find.byKey(const Key('hub_mark_button')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('hub_mark_button')));
    await waitFor(t, find.byKey(const Key('mark_bottom_bar')));
    await settle(t, 1500);
    await stub(t, '/__stub/mode?feature=attbulk&value=403');
    await tapChip(t, 0, 'absent');
    await settle(t, 800);
    await shot(t, '5a_dbg_after_edit');
    await waitFor(t, find.text('Review & submit'));
    await t.tap(find.byKey(const Key('submit_button')));
    await waitFor(t, find.byKey(const Key('attendance_confirm_dialog')));
    await t.tap(find.byKey(const Key('attendance_confirm_submit')));
    await waitFor(t, find.byKey(const Key('submit_retry')));
    await t.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await settle(t, 800);
    await shot(t, '5a_27_mark_error_403');
    await stub(t, '/__stub/mode?feature=attbulk&value=ok');
  });
}
