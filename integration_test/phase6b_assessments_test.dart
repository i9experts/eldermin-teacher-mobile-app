// Phase 6b (assessments, marks entry, report remarks, quiz grading, curriculum, library) walkthrough against the LOCAL STUB
// (tool/dev/stub_server.py + stub_6b.py, dummy data). Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_walkthrough.sh:
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase6b_assessments_test.dart
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

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

Finder get page => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(page, Offset(0, -dy));
  await settle(t, 600);
}

/// Stub student id (stub_server._oid): Grade 5 A student number [i] is 0x200 + i.
String sid(int i) => '64f${(0x200 + i).toRadixString(16).padLeft(21, '0')}';

Finder markField(int i) => find.byKey(Key('marks_field_${sid(i)}'));

Future<void> openAssessmentsFromClasses(WidgetTester t) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1200);
  await t.tap(find.byKey(const ValueKey('module_assessments')));
  await waitFor(t, find.byKey(const Key('asm_quiz_card')));
  await waitFor(t, find.text('Unit Test 1 - Fractions (DUMMY)'));
  await settle(t, 800);
}

Future<void> back(WidgetTester t) async {
  await t.pageBack();
  await settle(t, 1000);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 6b assessments walkthrough against the stub', (t) async {
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
    await waitFor(t, navLabel('Classes'));
    await settle(t, 2500);

    // ── Classes grid: every module live ──
    await t.tap(navLabel('Classes'));
    await settle(t, 1500);
    await shot(t, '6b_00_classes_grid_live');

    // ── Assessments list ──
    await t.tap(find.byKey(const ValueKey('module_assessments')));
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await waitFor(t, find.text('Unit Test 1 - Fractions (DUMMY)'));
    await settle(t, 1200);
    await shot(t, '6b_10_assessments_list');
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    await shot(t, '6b_11_assessments_all_statuses');
    await t.tap(find.byKey(const Key('chip_open')));
    await settle(t, 600);

    // ── Detail ──
    await t.tap(find.text('Unit Test 1 - Fractions (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await settle(t, 1000);
    await shot(t, '6b_12_assessment_detail');

    // ── Marks grid: partly filled (12 marks + 1 absent saved), then edit ──
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_save_button')));
    await waitFor(t, markField(0));
    await settle(t, 1200);
    await shot(t, '6b_20_marks_grid_partial');
    await scroll(t, 1500);
    await t.enterText(markField(13), '60'); // above the total of 50
    await t.enterText(markField(14), '38.5');
    await t.tap(find.byKey(Key('absent_${sid(15)}')));
    await t.tap(find.byKey(Key('exempt_${sid(16)}')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('marks_save_button')));
    await settle(t, 1000);
    await shot(t, '6b_21_marks_validation_error');
    await t.enterText(markField(13), '44');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('marks_save_button')));
    await waitFor(t, find.byKey(const Key('marks_confirm_save')));
    await shot(t, '6b_22_marks_save_summary', ms: 800);

    // ── Save fails (server error): state kept, banner with Retry ──
    await stub(t, '/__stub/mode?feature=marksbulk&value=500');
    await t.tap(find.byKey(const Key('marks_confirm_save')));
    await settle(t, 2500);
    await t.drag(page, const Offset(0, 4000)); // the banner sits at the top of the (scrolled) list
    await settle(t, 600);
    await waitFor(t, find.byKey(const Key('marks_save_error')));
    await shot(t, '6b_23_marks_save_error_state_kept');
    await stub(t, '/__stub/mode?feature=marksbulk&value=ok');
    await t.tap(find.text('Retry'));
    await waitFor(t, find.text('Saved marks for 4 students'));
    await settle(t, 600);
    await shot(t, '6b_24_marks_saved', ms: 600);
    await settle(t, 2500);
    await back(t);
    await back(t);

    // ── Locked sheets: partly verified (Mid-Term) and results published (Term 1) ──
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(t, 500);
    await waitFor(t, find.byKey(const Key('chip_all')));
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    await t.scrollUntilVisible(find.text('Mid-Term Exam (DUMMY)'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Mid-Term Exam (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_locked_note')));
    await settle(t, 1200);
    await shot(t, '6b_25_marks_partly_verified_locked');
    await back(t);
    await back(t);
    await t.scrollUntilVisible(find.text('Term 1 Result (DUMMY)'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Term 1 Result (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_warn_Mathematics')));
    await settle(t, 800);
    await shot(t, '6b_26_detail_results_published_warning');
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_status_warning')));
    await settle(t, 1200);
    await shot(t, '6b_27_marks_results_published_warning_editable');
    await back(t);
    await back(t);

    // ── A SCHEDULED assessment (Final Exam): no status gate, marks can be entered ──
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(t, 500);
    await waitFor(t, find.byKey(const Key('chip_all')));
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    await t.scrollUntilVisible(find.text('Final Exam (DUMMY)'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Final Exam (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await settle(t, 800);
    await shot(t, '6b_13_detail_scheduled_enter_marks_available');
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_save_button')));
    await waitFor(t, markField(0));
    await t.enterText(markField(0), '71');
    await settle(t, 900);
    await shot(t, '6b_29_marks_entry_scheduled_no_gate');
    // PLANNED backend behaviour (UNVERIFIED): the server refuses a row that was verified meanwhile
    await stub(t, '/__stub/mode?feature=marksbulk&value=lockedrows');
    await t.tap(find.byKey(const Key('marks_save_button')));
    await waitFor(t, find.byKey(const Key('marks_confirm_save')));
    await settle(t, 1500); // let the sheet finish sliding in before tapping its button
    await t.tap(find.byKey(const Key('marks_confirm_save')));
    await settle(t, 2500); // no drag here: pulling the list down would trigger pull-to-refresh and clear the banner
    await waitFor(t, find.byKey(const Key('marks_save_error')));
    await shot(t, '6b_30_marks_verified_rows_server_message');
    await stub(t, '/__stub/mode?feature=marksbulk&value=ok');
    await back(t);
    await back(t);

    // ── Empty grid (Grade 6 B Science, nothing entered yet) ──
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(t, 500);
    await waitFor(t, find.byKey(const Key('chip_all')));
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    await t.scrollUntilVisible(find.text('Class Test - Plants (DUMMY)'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Class Test - Plants (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_marks_Science')));
    await t.tap(find.byKey(const Key('asm_marks_Science')));
    await waitFor(t, find.byKey(const Key('marks_save_button')));
    await settle(t, 1500);
    await shot(t, '6b_19_marks_grid_empty');
    await back(t);
    await back(t);

    // ── Large class (229 students, two roster pages) ──
    await stub(t, '/__stub/mode?feature=bigclass&value=on');
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(t, 500);
    await t.scrollUntilVisible(find.text('Unit Test 1 - Fractions (DUMMY)'), 300, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 150));
    await settle(t, 500);
    await t.tap(find.text('Unit Test 1 - Fractions (DUMMY)'));
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.textContaining('229 students'));
    await settle(t, 1200);
    await shot(t, '6b_28_marks_large_class_229');
    await back(t);
    await back(t);
    await stub(t, '/__stub/mode?feature=bigclass&value=ok');

    // ── Report-card remarks (this teacher becomes the class teacher of Grade 5 A) ──
    await stub(t, '/__stub/class-teacher?email=teacher@stub.test&value=true');
    await t.runAsync(() => Get.find<AuthController>().refreshProfile(force: true));
    await settle(t, 500);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(t, 500);
    await waitFor(t, find.byKey(const Key('asm_remarks_card')));
    await settle(t, 1000);
    await t.tap(find.byKey(const Key('asm_remarks_card')));
    await waitFor(t, find.byType(TextField));
    await settle(t, 1500);
    await shot(t, '6b_40_report_remarks');
    await t.enterText(find.byType(TextField).first, 'A thoughtful learner who is improving steadily.');
    await settle(t, 500);
    await t.tap(find.textContaining('Save remarks').first);
    await waitFor(t, find.text('Remarks saved'));
    await shot(t, '6b_41_report_remarks_saved', ms: 600);
    await settle(t, 2500);
    await back(t);

    // ── Quiz grading ──
    await t.tap(find.byKey(const Key('asm_quiz_card')));
    await waitFor(t, find.text('2 ANSWERS TO MARK'));
    await settle(t, 1000);
    await shot(t, '6b_50_quiz_attempts_list');
    await t.tap(find.byKey(Key('qa_${'64f${(0xd00).toRadixString(16).padLeft(21, '0')}'}')));
    await waitFor(t, find.byKey(const Key('qa_effect_note')));
    await settle(t, 1200);
    await shot(t, '6b_51_quiz_attempt_grade');
    final q2 = find.descendant(of: find.byKey(Key('qa_mark_${'64f${(0xe20).toRadixString(16).padLeft(21, '0')}'}')), matching: find.byType(TextField));
    await t.ensureVisible(q2);
    await t.enterText(q2, '5');
    await settle(t, 600);
    await shot(t, '6b_52_quiz_mark_above_maximum');
    await t.enterText(q2, '3');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('qa_submit')));
    await waitFor(t, find.text('Save partial marks?'));
    await shot(t, '6b_53_quiz_partial_confirm', ms: 1800);
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await settle(t, 600);
    await back(t);
    await back(t);
    await back(t);

    // ── Curriculum and Library (More tab) ──
    await t.tap(navLabel('More'));
    await settle(t, 1200);
    await t.tap(find.text('Curriculum'));
    await waitFor(t, find.text('Mathematics Grade 5 (SNC)'));
    await settle(t, 1000);
    await shot(t, '6b_60_curriculum_list');
    await t.tap(find.text('Mathematics Grade 5 (SNC)'));
    await waitFor(t, find.text('M5-N-01'));
    await settle(t, 1000);
    await shot(t, '6b_61_curriculum_detail');
    await back(t);
    await back(t);
    await t.tap(find.text('Library'));
    await waitFor(t, find.byKey(const Key('lib_search')));
    await waitFor(t, find.text('Fractions Made Easy'));
    await settle(t, 1000);
    await shot(t, '6b_70_library_catalogue');
    await t.enterText(find.byKey(const Key('lib_search')), 'fractions');
    await settle(t, 2200);
    await t.tap(find.byKey(const Key('chip_available')));
    await settle(t, 1500);
    await shot(t, '6b_71_library_search_available');
    await back(t);

    // ── 403 states ──
    await stub(t, '/__stub/mode?feature=assessments&value=403');
    await t.tap(navLabel('Classes'));
    await settle(t, 1200);
    await t.tap(find.byKey(const ValueKey('module_assessments')));
    await waitFor(t, find.text("You don't have access"));
    await settle(t, 1000);
    await shot(t, '6b_90_assessments_403');
    await back(t);
    await stub(t, '/__stub/mode?feature=library&value=403');
    await t.tap(navLabel('More'));
    await settle(t, 1200);
    await t.tap(find.text('Library'));
    await waitFor(t, find.text("You don't have access"));
    await settle(t, 1000);
    await shot(t, '6b_91_library_403');
    await stub(t, '/__stub/reset-state');
  });
}
