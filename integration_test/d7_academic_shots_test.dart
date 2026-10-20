// D7 (academic screens) walkthrough against the LOCAL STUB
// (tool/dev/stub_server.py + stub_6b.py, dummy data). Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_walkthrough.sh:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d7_academic_shots_test.dart
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2000}) async {
  await t.pump(Duration(milliseconds: ms)); // let transitions finish BEFORE the marker, then give the capture real time
  print('SHOT:$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> stub(WidgetTester t, String path) async {
  print('STUB:$path');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder navLabel(String label) => find.descendant(of: find.byKey(const Key('app_shell_nav')), matching: find.text(label));

Finder get page => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(page, Offset(0, -dy));
  await settle(t, 600);
}

/// Stub student id (stub_server._oid): Grade 5 A student number [i] is 0x200 + i.
String sid(int i) => '64f${(0x200 + i).toRadixString(16).padLeft(21, '0')}';

Finder markField(int i) => find.byKey(Key('marks_field_${sid(i)}'));

Finder withKeyPrefix(String prefix) => find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix));

Future<void> back(WidgetTester t) async {
  await t.pageBack(); // finds the app bar's circle by its "Back" tooltip
  await settle(t, 900);
  if (find.byKey(const Key('confirm_dialog_confirm')).evaluate().isNotEmpty) {
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 900);
  }
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 5000));
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

Future<void> openAssessment(WidgetTester t, String title) async {
  await t.tap(find.byKey(const Key('chip_all')));
  await settle(t, 600);
  await t.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
  await t.tap(find.text(title));
  await settle(t, 2000);
}

Future<void> screens(WidgetTester t, String sc) async {
  // ── assessments: list, detail, marks entry (keyboard open), summary sheet ──
  await openClasses(t, 'assessments');
  await waitFor(t, find.text('Unit Test 1 - Fractions (DUMMY)'));
  await shot(t, 'd7_assessments_list_$sc');
  await t.tap(find.text('Unit Test 1 - Fractions (DUMMY)'));
  await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
  await shot(t, 'd7_assessment_detail_$sc');
  await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
  await waitFor(t, markField(1));
  await settle(t, 1500);
  await shot(t, 'd7_marks_entry_$sc');
  await t.tap(markField(1)); // the on-screen keyboard opens
  await settle(t, 1500);
  await t.enterText(markField(1), '41');
  await t.enterText(markField(2), '999'); // above the total: shows the error after Review & save
  await settle(t, 800);
  await shot(t, 'd7_marks_entry_keyboard_open_$sc');
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 800);
  await t.enterText(markField(2), '36');
  await settle(t, 500);
  await t.tap(find.byKey(const Key('marks_save_button')));
  await settle(t, 1500);
  await shot(t, 'd7_marks_summary_sheet_$sc');
  await t.tap(find.byKey(const Key('marks_cancel_save')));
  await settle(t, 600);
  await back(t);
  await back(t);

  // ── locked: results published ──
  await toTop(t);
  await openAssessment(t, 'Term 1 Result (DUMMY)');
  await waitFor(t, find.byKey(const Key('asm_locked_Mathematics')));
  await shot(t, 'd7_assessment_detail_locked_$sc');
  await t.tap(find.byKey(const Key('asm_view_Mathematics')));
  await waitFor(t, find.byKey(const Key('marks_lock_banner')));
  await settle(t, 1200);
  await shot(t, 'd7_marks_locked_readonly_$sc');
  await back(t);
  await back(t);

  // ── quiz grading + report remarks ──
  await toTop(t);
  await t.tap(find.byKey(const Key('asm_quiz_card')));
  await waitFor(t, find.byKey(const Key('quiz_subject_chips')));
  await settle(t, 1200);
  await shot(t, 'd7_quiz_list_$sc');
  await t.tap(withKeyPrefix('qa_').first);
  await settle(t, 2600);
  await shot(t, 'd7_quiz_detail_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // ── lesson plans ──
  await openClasses(t, 'lesson_plans');
  await shot(t, 'd7_lesson_plans_list_$sc');
  await t.tap(find.byWidgetPredicate((w) => w.key is ValueKey && RegExp(r'^lp_[0-9a-f]{8,}').hasMatch('${(w.key as ValueKey).value}')).first);
  await settle(t, 2600);
  await shot(t, 'd7_lesson_plan_detail_$sc');
  await back(t);
  await t.tap(find.byKey(const Key('lp_new_fab')));
  await settle(t, 2600);
  await shot(t, 'd7_lesson_plan_form_$sc');
  await back(t);
  await t.tap(find.byKey(const Key('lp_upload_action')));
  await settle(t, 2200);
  await shot(t, 'd7_lesson_plan_upload_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // ── syllabus ──
  await openClasses(t, 'syllabus');
  await shot(t, 'd7_syllabus_list_$sc');
  await t.tap(withKeyPrefix('syl_6').first);
  await settle(t, 2600);
  await shot(t, 'd7_syllabus_detail_$sc');
  await back(t);
  await t.tap(find.byKey(const Key('syl_planner_card')));
  await settle(t, 2600);
  await shot(t, 'd7_syllabus_planner_$sc');
  await back(t);
  await back(t);
  await homeTab(t);

  // ── curriculum + library (More tab) ──
  await openMore(t, 'Curriculum');
  await shot(t, 'd7_curriculum_list_$sc');
  await t.tap(withKeyPrefix('cur_6').first);
  await settle(t, 2200);
  await shot(t, 'd7_curriculum_detail_$sc');
  await back(t);
  await back(t);
  await homeTab(t);
  await openMore(t, 'Library');
  await shot(t, 'd7_library_$sc');
  await back(t);
  await homeTab(t);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D7 academic walkthrough', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'teacher@stub.test');
    await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await waitFor(t, find.byKey(const Key('app_shell_nav')));
    await settle(t, 4000);
    await screens(t, 'normal');
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1200);
    await screens(t, 'scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    // report remarks need the class-teacher role: the stub flips it for this teacher
    await stub(t, '/__stub/class-teacher?email=teacher@stub.test&value=true');
    await t.runAsync(() => Get.find<AuthController>().refreshProfile(force: true));
    await settle(t, 800);
    for (final sc in ['normal', 'scale13']) {
      if (sc == 'scale13') binding.platformDispatcher.textScaleFactorTestValue = 1.3;
      await openClasses(t, 'assessments');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await settle(t, 600);
      await waitFor(t, find.byKey(const Key('asm_remarks_card')));
      await toTop(t);
      await t.tap(find.byKey(const Key('asm_remarks_card')));
      await waitFor(t, find.byType(TextField));
      await settle(t, 1500);
      await shot(t, 'd7_report_remarks_$sc');
      await t.tap(find.byType(TextField).first);
      await settle(t, 1500);
      await shot(t, 'd7_report_remarks_keyboard_open_$sc');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t, 600);
      await back(t);
      await back(t);
      await homeTab(t);
    }
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
