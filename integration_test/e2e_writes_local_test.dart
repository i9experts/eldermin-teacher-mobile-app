// END-TO-END WRITE flows against the LOCAL backend (isolated DB eldermin_teacher_verify; NOT staging, NOT the stub, NO shim: the backend's own
// id-match plugin is on). One scenario per run, chosen with --dart-define=E2E_SCENARIO=<hw|lp|marks|remarks|quiz|deeplink>; run through
// tool/dev/capture_e2e_writes.sh (watchdog, screenshots, DB actions between taps). Credentials only via --dart-define, never stored.
// Report: eldermin-teacher-app-docs/LOCAL_VERIFICATION.md, section "End-to-end writes (no shim, backend 5653b41)".
import 'dart:io';
import 'package:eldermin_teacher_app/app/common/services/deep_link_service.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_common.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

/// The documented injection point of the native document picker (the same `Get.put<AttachmentPicker>` seam the homework controller reads):
/// the file is a REAL temp file with real bytes; the upload and the assignment POST that follow are real network calls.
class TestAttachmentPicker implements AttachmentPicker {
  List<PickedAttachment> next = const [];
  @override
  Future<List<PickedAttachment>> pickDocuments() async => next;
  @override
  Future<List<PickedAttachment>> pickPhotos() async => const [];
}

PickedAttachment tempPdf(String name) {
  final f = File('${Directory.systemTemp.path}/$name')..writeAsBytesSync('%PDF-1.4\n% local verification dummy attachment\n'.codeUnits);
  return PickedAttachment(name: name, path: f.path, size: f.lengthSync());
}

String chipLabel(int i) {
  final chip = find.byKey(ValueKey('class_chip_$i'));
  final txt = find.descendant(of: chip, matching: find.byType(Text));
  return txt.evaluate().isEmpty ? '' : (txt.evaluate().first.widget as Text).data ?? '';
}

/// Picks the day `dayOfMonth` in the app's own date sheet (bottom sheet with a GridView of day cells).
Future<void> pickDay(WidgetTester t, Key pickerKey, int dayOfMonth) async {
  await t.ensureVisible(find.byKey(pickerKey));
  await settle(t, 300);
  final top = t.getTopLeft(find.byKey(pickerKey)).dy;
  if (top < 260) {
    // ensureVisible can leave the field under the app bar: scroll it down a little (bounded, one drag)
    await t.drag(find.byType(Scrollable).first, Offset(0, 300 - top));
    await settle(t, 500);
  }
  await t.tap(find.byKey(pickerKey));
  await waitFor(t, find.text('Select date'));
  await settle(t, 600);
  await t.tap(find.descendant(of: find.byType(GridView), matching: find.text('$dayOfMonth')).first);
  await settle(t, 900);
}

int soonDay() {
  final n = DateTime.now();
  final last = DateTime(n.year, n.month + 1, 0).day;
  return n.day + 3 <= last ? n.day + 3 : n.day;
}

Future<void> openAssessment(WidgetTester t, String title) async {
  await openClassesModule(t, 'assessments');
  await waitFor(t, find.byKey(const Key('asm_quiz_card')));
  await settle(t, 2500);
  await t.tap(find.byKey(const Key('chip_all')));
  await settle(t, 800);
  await t.scrollUntilVisible(find.text(title), 250, scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  await tapText(t, title);
  await settle(t, 1500);
}

Future<void> openMarksGrid(WidgetTester t, String subject) async {
  await t.tap(find.byKey(Key('asm_marks_$subject')));
  await waitFor(t, find.byKey(const Key('marks_save_button')));
  await settle(t, 2500);
}

/// Taps "Save", the confirm sheet's "Save" and waits for the outcome (success = no unsaved changes; failure = the save banner).
Future<String> saveMarks(WidgetTester t) async {
  await t.tap(find.byKey(const Key('marks_save_button')));
  await waitFor(t, find.byKey(const Key('marks_confirm_save')));
  await settle(t, 600);
  await shot(t, 'marks_confirm_sheet');
  await t.tap(find.byKey(const Key('marks_confirm_save')));
  final done = await waitForAny(t, [find.byKey(const Key('marks_save_error')), find.text('No changes yet')], seconds: 40);
  await settle(t, 800);
  if (!done) return 'TIMEOUT';
  return find.byKey(const Key('marks_save_error')).evaluate().isNotEmpty ? 'FAILED' : 'SAVED';
}

String bannerText(WidgetTester t, Key k) {
  final f = find.descendant(of: find.byKey(k), matching: find.byType(Text));
  return [for (final e in f.evaluate()) (e.widget as Text).data ?? ''].join(' | ');
}

// ---------------------------------------------------------------- scenario: homework create (+ attachment) as class teacher B
Future<void> hwScenario(WidgetTester t, TestAttachmentPicker picker) async {
  await step(t, 'B login', () async => signIn(t, e2eClassEmail, e2eClassPassword));
  await step(t, 'B homework create WITH attachment (upload is real; local backend has no S3 credentials)', () async {
    await openClassesModule(t, 'homework');
    await waitFor(t, find.byKey(const Key('hw_new_fab')));
    await settle(t, 1500);
    await shot(t, 'B_homework_list_before');
    await t.tap(find.byKey(const Key('hw_new_fab')));
    await waitFor(t, find.byKey(const Key('hw_title_field')));
    await settle(t, 1200);
    final n = idKeyedCount();
    final labels = [for (var i = 0; i < n; i++) chipLabel(i)];
    print('INFO class chips for B: $labels');
    var idx = labels.indexWhere((l) => l.contains('5') && l.contains('B'));
    if (idx < 0) idx = 0;
    await t.tap(find.byKey(ValueKey('class_chip_$idx')));
    await settle(t, 1200);
    final subjects = keyPrefix('subject_');
    print('INFO subject chips: ${subjects.evaluate().map(keyOf).toList()}');
    await t.tap(subjects.first);
    await settle(t, 500);
    await t.enterText(find.byKey(const Key('hw_title_field')), 'E2E homework with attachment');
    await t.enterText(find.byKey(const Key('hw_desc_field')), 'Local end-to-end verification (dummy data).');
    await pickDay(t, const Key('hw_due_picker'), soonDay());
    await t.enterText(find.byKey(const Key('hw_total_field')), '20');
    await t.enterText(find.byKey(const Key('hw_pass_field')), '8');
    await settle(t, 600);
    // attachment: the native picker is replaced at the AttachmentPicker seam; everything after the pick is real
    picker.next = [tempPdf('e2e_worksheet.pdf')];
    await t.scrollUntilVisible(find.byKey(const Key('hw_add_attachment')), 250, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('hw_add_attachment')));
    await waitFor(t, find.byKey(const Key('hw_pick_files')));
    await t.tap(find.byKey(const Key('hw_pick_files')));
    await waitFor(t, find.byKey(const ValueKey('att_u0')));
    final ok = await waitForAny(t, [find.byKey(const ValueKey('retry_u0')), find.descendant(of: find.byKey(const ValueKey('att_u0')), matching: find.byIcon(Icons.check_circle_rounded))], seconds: 60);
    await settle(t, 800);
    final failed = find.byKey(const ValueKey('retry_u0')).evaluate().isNotEmpty;
    print('INFO upload outcome: ${!ok ? 'TIMEOUT' : failed ? 'FAILED' : 'DONE'}; error text on screen: ${find.byKey(const ValueKey('att_err_u0')).evaluate().isEmpty ? '(none)' : textOf(t, find.byKey(const ValueKey('att_err_u0')))}');
    await shot(t, 'B_homework_attachment_upload_outcome');
    if (failed) {
      // one retry (bounded): same outcome expected
      await t.tap(find.byKey(const ValueKey('retry_u0')));
      await settle(t, 500);
      await waitForAny(t, [find.byKey(const ValueKey('retry_u0'))], seconds: 60);
      await settle(t, 600);
      print('INFO after Retry: failed again = ${find.byKey(const ValueKey('retry_u0')).evaluate().isNotEmpty}');
      // submit refused while a failed upload is attached
      await t.tap(find.byKey(const Key('hw_submit')));
      await settle(t, 1200);
      final confirmShown = find.byKey(const Key('confirm_dialog_confirm')).evaluate().isNotEmpty;
      print('INFO assign with a failed attachment: confirm dialog shown = $confirmShown');
      await shot(t, 'B_homework_assign_refused_with_failed_attachment');
      if (confirmShown) await confirmDiscardIfShown(t); // (would send the form; not expected)
      // remove the failed attachment, then create WITHOUT it
      await settle(t, 4500); // let the snackbar go away (it overlays the row)
      await t.ensureVisible(find.byKey(const ValueKey('remove_u0')));
      await settle(t, 500);
      await t.tap(find.byKey(const ValueKey('remove_u0')));
      await settle(t, 600);
    }
    await shot(t, 'B_homework_form_ready_without_attachment');
    await t.tap(find.byKey(const Key('hw_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 600);
    await shot(t, 'B_homework_assign_confirm');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('hw_new_fab')), seconds: 40);
    await waitFor(t, find.text('E2E homework with attachment'), seconds: 20);
    await settle(t, 1000);
    expect(find.byKey(const Key('hw_submit_error')), findsNothing);
    await shot(t, 'B_homework_in_list_after_create');
    await t.tap(find.text('E2E homework with attachment').first);
    await waitFor(t, find.byKey(const Key('hw_view_submissions')));
    await settle(t, 1200);
    await shot(t, 'B_homework_detail_after_create');
    await leaveToShell(t);
  });
  await step(t, 'B sign out', () async => signOutViaUi(t));
}

int idKeyedCount() => find.byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp(r'^class_chip_\d+$').hasMatch((w.key as ValueKey<String>).value)).evaluate().length;

// ---------------------------------------------------------------- scenario: lesson plan draft -> edit -> submit as teacher A
Future<void> lpScenario(WidgetTester t) async {
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await step(t, 'A lesson plan: save draft, edit, submit for approval', () async {
    await openClassesModule(t, 'lesson_plans');
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await settle(t, 1500);
    await shot(t, 'A_lessonplans_before');
    await t.tap(find.byKey(const Key('lp_new_fab')));
    await waitFor(t, find.byKey(const Key('lp_topic_field')));
    await settle(t, 1200);
    final n = idKeyedCount();
    final labels = [for (var i = 0; i < n; i++) chipLabel(i)];
    print('INFO class chips for A: $labels');
    var idx = labels.indexWhere((l) => l.contains('5') && l.contains('A'));
    if (idx < 0) idx = 0;
    await t.tap(find.byKey(ValueKey('class_chip_$idx')));
    await settle(t, 1000);
    await t.tap(find.byKey(const Key('subject_Mathematics')));
    await settle(t, 500);
    await t.enterText(find.byKey(const Key('lp_topic_field')), 'E2E fractions lesson');
    await pickDay(t, const Key('lp_date_picker'), DateTime.now().day);
    await t.enterText(find.byKey(const Key('lp_duration_field')), '40');
    await t.enterText(find.byKey(const Key('lp_desc_field')), 'Local end-to-end verification (dummy data).');
    await t.scrollUntilVisible(find.byKey(const Key('lp_add_objective')), 250, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('lp_add_objective')));
    await settle(t, 500);
    final objs = find.byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp(r'^lp_obj_[^r]').hasMatch((w.key as ValueKey<String>).value) && !(w.key as ValueKey<String>).value.startsWith('lp_obj_remove_'));
    await t.enterText(objs.last, 'Add fractions with like denominators');
    await settle(t, 600);
    await shot(t, 'A_lessonplan_new_filled');
    await t.tap(find.byKey(const Key('lp_save_draft')));
    await waitFor(t, find.byKey(const Key('lp_new_fab')), seconds: 40);
    await waitFor(t, find.text('E2E fractions lesson'), seconds: 20);
    await settle(t, 1000);
    await shot(t, 'A_lessonplan_draft_in_list');
    await t.tap(find.text('E2E fractions lesson').first);
    await waitFor(t, find.byKey(const Key('lp_edit')));
    await settle(t, 1500);
    await shot(t, 'A_lessonplan_draft_detail');
    await t.tap(find.byKey(const Key('lp_edit')));
    await waitFor(t, find.byKey(const Key('lp_topic_field')));
    await settle(t, 1000);
    await t.enterText(find.byKey(const Key('lp_topic_field')), 'E2E fractions lesson (edited)');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('lp_save_draft')));
    await waitFor(t, find.byKey(const Key('lp_submit')), seconds: 40);
    await settle(t, 1500);
    expect(find.text('E2E fractions lesson (edited)'), findsWidgets);
    await shot(t, 'A_lessonplan_after_edit_detail');
    await t.tap(find.byKey(const Key('lp_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 600);
    await shot(t, 'A_lessonplan_submit_confirm');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('lp_under_review')), seconds: 40);
    await settle(t, 1200);
    expect(find.byKey(const Key('lp_action_error')), findsNothing);
    await shot(t, 'A_lessonplan_submitted_detail');
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await settle(t, 1200);
    await shot(t, 'A_lessonplans_list_after_submit');
    await leaveToShell(t);
  });
  await step(t, 'A sign out', () async => signOutViaUi(t));
}

// ---------------------------------------------------------------- scenario: marks bulk save + stale-client server rejections (A)
Future<void> marksScenario(WidgetTester t) async {
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  late List<String> ids;
  await step(t, 'A marks: bulk save of 3 marks (real POST /assessments/marks/bulk)', () async {
    await openAssessment(t, 'Unit Test 1 - Mathematics');
    await openMarksGrid(t, 'Mathematics');
    await shot(t, 'A_marks_grid_before');
    final fields = keyPrefix('marks_field_');
    ids = [for (final e in fields.evaluate().take(4)) keyOf(e).substring('marks_field_'.length)];
    print('INFO first rows (ids): $ids  (fields on screen: ${fields.evaluate().length})');
    await t.enterText(find.byKey(Key('marks_field_${ids[0]}')), '41');
    await t.enterText(find.byKey(Key('marks_field_${ids[1]}')), '36');
    await t.enterText(find.byKey(Key('marks_field_${ids[2]}')), '44');
    await settle(t, 600);
    await shot(t, 'A_marks_grid_typed');
    final r = await saveMarks(t);
    print('INFO marks save outcome: $r ${r == 'FAILED' ? bannerText(t, const Key('marks_save_error')) : ''}');
    expect(r, 'SAVED');
    await shot(t, 'A_marks_saved');
  });
  await step(t, 'A marks (a) STALE total: lower the subject total in the DB while the grid is open, then save 30', () async {
    await leaveScreen(t);
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await openMarksGrid(t, 'Mathematics');
    await dbAction(t, 'lower_total'); // DB: Unit Test 1 Mathematics totalMarks 50 -> 20 (client still believes 50)
    await t.enterText(find.byKey(Key('marks_field_${ids[3]}')), '30');
    await settle(t, 500);
    final r = await saveMarks(t);
    final msg = find.byKey(const Key('marks_save_error')).evaluate().isEmpty ? '(none)' : bannerText(t, const Key('marks_save_error'));
    print('INFO (a) over-total stale save outcome: $r; banner: $msg');
    print('INFO (a) typed value kept in the field: "${fieldText(t, find.byKey(Key('marks_field_${ids[3]}')))}"');
    await shot(t, 'A_marks_server_400_over_total');
    expect(r, 'FAILED');
    expect(fieldText(t, find.byKey(Key('marks_field_${ids[3]}'))), '30', reason: 'typed value must be kept after a server 400');
    await dbAction(t, 'restore_total');
  });
  await step(t, 'A marks (b) VERIFIED row: verify a student in the DB while the grid is open, then change that student', () async {
    await leaveScreen(t); // dirty -> the app's Discard dialog -> Discard (never Cancel)
    await waitFor(t, find.byKey(const Key('asm_marks_Mathematics')));
    await openMarksGrid(t, 'Mathematics');
    await dbAction(t, 'verify_row', arg: ids[0]);
    await t.enterText(find.byKey(Key('marks_field_${ids[0]}')), '12');
    await t.enterText(find.byKey(Key('marks_field_${ids[1]}')), '13');
    await settle(t, 500);
    final r = await saveMarks(t);
    final msg = find.byKey(const Key('marks_save_error')).evaluate().isEmpty ? '(none)' : bannerText(t, const Key('marks_save_error'));
    print('INFO (b) verified-row save outcome: $r; banner: $msg');
    final locked = find.byKey(Key('marks_lock_${ids[0]}')).evaluate().isNotEmpty;
    print('INFO (b) row locked in the grid after the 409: $locked; other typed value kept: "${fieldText(t, find.byKey(Key('marks_field_${ids[1]}')))}"');
    await shot(t, 'A_marks_server_409_verified_row_locked');
    expect(r, 'FAILED');
    expect(locked, isTrue, reason: 'the verified row must become locked');
    expect(fieldText(t, find.byKey(Key('marks_field_${ids[1]}'))), '13', reason: 'other typed values must be kept');
    await leaveToShell(t);
  });
  await step(t, 'A sign out', () async => signOutViaUi(t));
}

// ---------------------------------------------------------------- scenario: report-card remarks (B saves, A blocked)
Future<void> remarksScenario(WidgetTester t) async {
  await step(t, 'B login', () async => signIn(t, e2eClassEmail, e2eClassPassword));
  await step(t, 'B remarks: type and save classTeacherRemarks', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_remarks_card')));
    await settle(t, 2000);
    await t.tap(find.byKey(const Key('asm_remarks_card')));
    await waitFor(t, idKeyed('rc_'), seconds: 40);
    await settle(t, 1500);
    await shot(t, 'B_remarks_list');
    final inputs = keyPrefix('remarks_input_');
    // pick the last-loaded card on screen that currently has no remarks (seed: the first 3 have 'Excellent work')
    final id = keyOf(inputs.evaluate().last).substring('remarks_input_'.length);
    print('INFO remarks card id (report card): $id; cards on screen with input: ${inputs.evaluate().length}');
    await t.enterText(find.byKey(Key('remarks_input_$id')), 'E2E remark: steady progress this term.');
    await settle(t, 600);
    await shot(t, 'B_remarks_typed');
    await t.ensureVisible(find.byKey(Key('remarks_save_$id')));
    await settle(t, 300);
    await t.tap(find.byKey(Key('remarks_save_$id')));
    await settle(t, 3000);
    final err = find.byKey(Key('remarks_error_$id')).evaluate().isNotEmpty ? textOf(t, find.byKey(Key('remarks_error_$id'))) : '(none)';
    print('INFO remarks save error shown: $err');
    await shot(t, 'B_remarks_saved');
    expect(err, '(none)');
    await leaveToShell(t);
  });
  await step(t, 'B sign out', () async => signOutViaUi(t));
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await step(t, 'A (not class teacher): remarks card hidden', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await settle(t, 2000);
    final hidden = find.byKey(const Key('asm_remarks_card')).evaluate().isEmpty;
    print('INFO A: report-remarks entry hidden = $hidden');
    await shot(t, 'A_assessments_no_remarks_card');
    expect(hidden, isTrue);
    await leaveToShell(t);
  });
  await step(t, 'A sign out', () async => signOutViaUi(t));
}

// ---------------------------------------------------------------- scenario: quiz grading (B class teacher, then A)
Future<void> gradeFirstAttempt(WidgetTester t, String who, {required List<String> marks}) async {
  final rows = idKeyed('qa_');
  final id = keyOf(rows.evaluate().first).substring(3);
  await t.tap(rows.first);
  await waitFor(t, find.byKey(const Key('qa_submit')), seconds: 30);
  await settle(t, 1500);
  await shot(t, '${who}_quiz_attempt_detail');
  final fields = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('qa_mark_') && !(w.key as ValueKey<String>).value.startsWith('qa_mark_error_'));
  print('INFO $who grading attempt $id: manual mark fields = ${fields.evaluate().length}');
  for (var i = 0; i < fields.evaluate().length && i < marks.length; i++) {
    await t.enterText(find.descendant(of: fields.at(i), matching: find.byType(EditableText)).first, marks[i]);
  }
  await settle(t, 600);
  await t.ensureVisible(find.byKey(const Key('qa_submit')));
  await t.tap(find.byKey(const Key('qa_submit')));
  await settle(t, 1500);
  if (find.byKey(const Key('confirm_dialog_confirm')).evaluate().isNotEmpty) {
    await shot(t, '${who}_quiz_submit_confirm');
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  }
  await settle(t, 3500);
  final err = find.byKey(const Key('qa_error')).evaluate().isNotEmpty ? bannerText(t, const Key('qa_error')) : '(none)';
  print('INFO $who grade save error: $err');
  await shot(t, '${who}_quiz_after_grade');
  expect(err, '(none)');
}

Future<void> quizScenario(WidgetTester t) async {
  await step(t, 'B login', () async => signIn(t, e2eClassEmail, e2eClassPassword));
  await step(t, 'B quiz list (class teacher: all subjects of own class) and grade one attempt', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await settle(t, 2000);
    await t.tap(find.byKey(const Key('asm_quiz_card')));
    await settle(t, 3500);
    expectNoBadStates('B quiz');
    final n = idKeyed('qa_').evaluate().length;
    print('INFO B quiz attempts listed: $n; subject chips present: ${find.byKey(const Key('quiz_subject_chips')).evaluate().isNotEmpty}; chips: ${keyPrefix('quiz_chip_').evaluate().map(keyOf).toList()}');
    await shot(t, 'B_quiz_list');
    expect(n, 2, reason: 'class teacher of 5-A sees the 2 submitted 5-A attempts (all subjects)');
    await gradeFirstAttempt(t, 'B', marks: ['4', '2']);
    await leaveScreen(t);
    await settle(t, 2500);
    final after = idKeyed('qa_').evaluate().length;
    print('INFO B quiz attempts listed after grading: $after');
    await shot(t, 'B_quiz_list_after_grading');
    await leaveToShell(t);
  });
  await step(t, 'B sign out', () async => signOutViaUi(t));
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await step(t, 'A quiz list (subject teacher: own subject/classes only), grade one attempt', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await settle(t, 2000);
    await t.tap(find.byKey(const Key('asm_quiz_card')));
    await settle(t, 3500);
    expectNoBadStates('A quiz');
    final n = idKeyed('qa_').evaluate().length;
    print('INFO A quiz attempts listed: $n; subject chips present: ${find.byKey(const Key('quiz_subject_chips')).evaluate().isNotEmpty}; chips: ${keyPrefix('quiz_chip_').evaluate().map(keyOf).toList()}');
    await shot(t, 'A_quiz_list');
    await dbAction(t, 'manual_verified_mark_for_remaining_5a'); // DB: a verified, manually entered mark for the remaining 5-A attempt's student
    await gradeFirstAttempt(t, 'A', marks: ['5', '3']);
    await leaveScreen(t);
    await settle(t, 2500);
    print('INFO A quiz attempts listed after grading: ${idKeyed('qa_').evaluate().length}');
    await shot(t, 'A_quiz_list_after_grading');
    await leaveToShell(t);
  });
  await step(t, 'A sign out', () async => signOutViaUi(t));
}

// ---------------------------------------------------------------- scenario: deep links (reset-password, login token, account switch)
Future<void> deepScenario(WidgetTester t) async {
  final links = Get.find<DeepLinkService>();
  const osHandled = false;
  await step(t, 'reset-password link injected at DeepLinkService.handleUri (real token, real backend)', () async {
    if (!osHandled) {
      links.handleUri(Uri.parse('eldermin-teacher://reset-password?token=$e2eResetToken'));
    }
    await waitFor(t, find.text('Set a new password'), seconds: 20);
    await waitFor(t, find.text('Update password'), seconds: 20);
    await settle(t, 800);
    await shot(t, 'reset_screen_token_prefilled');
    final fs = find.descendant(of: find.byType(Form).last, matching: find.byType(TextFormField)); // the reset form only (login below keeps its fields in the tree)
    await t.enterText(fs.at(0), e2eResetNewPassword);
    await t.enterText(fs.at(1), e2eResetNewPassword);
    await settle(t, 500);
    await t.tap(find.text('Update password'));
    await settle(t, 3500);
    await shot(t, 'reset_after_update');
    print('INFO after Update password: route=${Get.currentRoute}; on login=${find.text('Sign in').evaluate().isNotEmpty}; error banner=${find.text('This reset link is invalid or has expired').evaluate().isNotEmpty}');
  });
  await step(t, 'same reset link a second time must be refused (single-use)', () async {
    if (find.text('Sign in').evaluate().isEmpty) await settle(t, 1500);
    links.handleUri(Uri.parse('eldermin-teacher://reset-password?token=$e2eResetToken'));
    await waitFor(t, find.text('Update password'), seconds: 20);
    final fs = find.descendant(of: find.byType(Form).last, matching: find.byType(TextFormField)); // the reset form only (login below keeps its fields in the tree)
    await t.enterText(fs.at(0), e2eResetNewPassword);
    await t.enterText(fs.at(1), e2eResetNewPassword);
    await t.tap(find.text('Update password'));
    await settle(t, 3500);
    final refused = find.textContaining('invalid or has expired').evaluate().isNotEmpty;
    print('INFO reused reset token refused in the app: $refused');
    await shot(t, 'reset_token_reuse_refused');
    expect(refused, isTrue);
    await leaveToShellOrLogin(t);
  });
  await step(t, 'login link (JWT of teacher A) while signed out -> signed in, role gate passed', () async {
    links.handleUri(Uri.parse('eldermin-teacher://login?token=$e2eLoginJwt&slug=$e2eSlug'));
    await waitFor(t, find.byType(BottomNavigationBar), seconds: 30);
    await settle(t, 2500);
    await waitFor(t, find.text("Today's classes"), seconds: 20);
    final auth = Get.find<AuthController>();
    print('INFO login link: authenticated=${auth.status.value == AuthStatus.authenticated}, isClassTeacher=${auth.isClassTeacher}, staffId present=${auth.staffId != null}');
    await shot(t, 'login_link_signed_in_home');
  });
  await step(t, 'login link while already signed in -> account-switch dialog (Cancel keeps session, then confirm switches)', () async {
    links.handleUri(Uri.parse('eldermin-teacher://login?token=$e2eLoginJwt2&slug=$e2eSlug'));
    await waitFor(t, find.text('Switch account?'), seconds: 15);
    await settle(t, 600);
    await shot(t, 'account_switch_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await settle(t, 1200);
    expect(find.byType(BottomNavigationBar), findsOneWidget, reason: 'Cancel keeps the current session');
    print('INFO account switch: Cancel kept the session');
    links.handleUri(Uri.parse('eldermin-teacher://login?token=$e2eLoginJwt2&slug=$e2eSlug'));
    await waitFor(t, find.text('Switch account?'), seconds: 15);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byType(BottomNavigationBar), seconds: 30);
    await settle(t, 2500);
    print('INFO account switch: confirm signed out and signed in again with the link token; isClassTeacher now=${Get.find<AuthController>().isClassTeacher} (B is the class teacher)');
    await shot(t, 'account_switch_confirmed_home');
  });
  await osHandOff(t);
}

Future<void> osHandOff(WidgetTester t) async {
  await step(t, 'OS hand-off: xcrun simctl openurl reset-password (host script)', () async {
    print('OSLINK:reset');
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 7)));
    await t.pump(const Duration(milliseconds: 500));
    print('INFO after OS openurl: route=${Get.currentRoute}, reset screen shown=${find.text('Set a new password').evaluate().isNotEmpty}');
    await shot(t, 'os_openurl_reset_after_7s');
  });
}

Future<void> leaveToShellOrLogin(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    if (find.text('Sign in').evaluate().isNotEmpty) return;
    await leaveScreen(t);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = [e2eBaseUrl, e2eTeacherEmail, e2eTeacherPassword, e2eClassEmail, e2eClassPassword, e2eScenario].every((e) => e.isNotEmpty);
  if (!configured) print('SKIPPED e2e_writes_local_test: pass --dart-define for API_BASE_URL, LOCAL_* credentials and E2E_SCENARIO (see the header).');
  testWidgets('E2E writes against the LOCAL backend: $e2eScenario', skip: !configured, timeout: const Timeout(Duration(minutes: 12)), (t) async {
    final picker = TestAttachmentPicker();
    Get.put<AttachmentPicker>(picker, permanent: true);
    await startRun(t, app.main);
    switch (e2eScenario) {
      case 'hw':
        await hwScenario(t, picker);
      case 'lp':
        await lpScenario(t);
      case 'marks':
        await marksScenario(t);
      case 'remarks':
        await remarksScenario(t);
      case 'quiz':
        await quizScenario(t);
      case 'oslink':
        await osHandOff(t);
      case 'deeplink':
        await deepScenario(t);
      default:
        throw TestFailure('unknown E2E_SCENARIO $e2eScenario');
    }
    print('E2E_DONE scenario=$e2eScenario failures=${e2eFailures.length}');
    for (final f in e2eFailures) print('FAILED_STEP $f');
    expect(e2eFailures, isEmpty);
  });
}
