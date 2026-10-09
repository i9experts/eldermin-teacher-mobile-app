// PHASE 7 PART 2 (+ the 2026-10-08 re-check) END-TO-END flows against the LOCAL backend (isolated DB eldermin_teacher_verify; NOT staging, NOT the stub,
// NO shim; backend 265fcfa). One scenario per run: --dart-define=P7_SCENARIO=<marks|b5|safe|profile|help|cal|hung>, run through tool/dev/capture_p7c.sh
// (watchdog, screenshots, DB actions between taps, logging/hanging proxy). Credentials only via --dart-define. Report: LOCAL_VERIFICATION.md section 14.
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'dart:io';

import 'package:eldermin_teacher_app/app/modules/students/views/widgets/student_widgets.dart';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'p7c_local_common.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

Finder get firstMarkField => idKeyed('marks_field_').first;

Future<void> toAssessmentsList(WidgetTester t) async {
  await openClassesModule(t, 'assessments');
  await waitFor(t, find.byKey(const Key('asm_quiz_card')));
  await settle(t, 1500);
}

Future<void> openAssessment(WidgetTester t, String fixture) async {
  if (find.byKey(const Key('chip_all')).evaluate().isEmpty) await toTop(t);
  if (find.byKey(const Key('chip_all')).evaluate().isEmpty) await toAssessmentsList(t);
  await t.tap(find.byKey(const Key('chip_all')));
  await settle(t, 800);
  final tile = find.byKey(ValueKey('asm_${pid(fixture)}'));
  await t.scrollUntilVisible(tile, 250, scrollable: find.byType(Scrollable).first, maxScrolls: 30);
  await settle(t, 400);
  await t.tap(tile);
  await waitFor(t, find.byKey(const ValueKey('asm_subject_Mathematics')));
  await settle(t, 1200);
}

Future<void> leaveGrid(WidgetTester t) async {
  await leaveScreen(t);
  final leave = find.widgetWithText(TextButton, 'Leave'); // the marks grid asks "Leave without saving?" (Leave = discard, never Cancel)
  if (leave.evaluate().isNotEmpty) {
    await t.tap(leave.first);
    await settle(t, 900);
  }
}

Future<void> backTwice(WidgetTester t) async {
  await leaveGrid(t);
  await leaveGrid(t);
  await toTop(t);
  await waitFor(t, find.byKey(const Key('chip_all')));
  await settle(t, 800);
}

bool fieldEnabled(WidgetTester t, Finder f) => t.widget<TextField>(f).enabled ?? true;

// =============================================================================================================== 5a-5d marks (teacher A: teaches Mathematics in 5-A; B, a class teacher who does not teach the subject, gets view-only access)
Future<void> marksScenario(WidgetTester t) async {
  final hwPicker = FakeAttachmentPicker();
  Get.put<AttachmentPicker>(hwPicker, permanent: true);
  await step(t, 'A login (subject teacher of Mathematics 5-A)', () async {
    await bootAndSignIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
  });
  await step(t, '5a published assessment: read-only grid + lock banner', () async {
    await toAssessmentsList(t);
    await openAssessment(t, 'ASM_published');
    expectTrue('detail shows the lock text', find.byKey(const ValueKey('asm_locked_Mathematics')).evaluate().isNotEmpty);
    expectTrue('no "Enter marks" action', find.byKey(const Key('asm_marks_Mathematics')).evaluate().isEmpty);
    await pshot(t, 'published_detail_locked');
    await t.tap(find.byKey(const Key('asm_view_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_lock_banner')));
    await waitFor(t, idKeyed('marks_field_'));
    await settle(t, 1200);
    expectTrue('first marks field disabled', !fieldEnabled(t, firstMarkField));
    expectTrue('no Review & save button', find.byKey(const Key('marks_save_button')).evaluate().isEmpty);
    result('lock banner text', textOf(t, find.descendant(of: find.byKey(const Key('marks_lock_banner')), matching: find.byType(Text)).first));
    await pshot(t, 'published_marks_readonly_banner');
    await backTwice(t);
  });
  await step(t, '5a cancelled assessment: read-only grid + lock banner', () async {
    await openAssessment(t, 'ASM_cancelled');
    await t.tap(find.byKey(const Key('asm_view_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_lock_banner')));
    await waitFor(t, idKeyed('marks_field_'));
    await settle(t, 1000);
    expectTrue('first marks field disabled', !fieldEnabled(t, firstMarkField));
    expectTrue('no Review & save button', find.byKey(const Key('marks_save_button')).evaluate().isEmpty);
    result('lock banner text', textOf(t, find.descendant(of: find.byKey(const Key('marks_lock_banner')), matching: find.byType(Text)).first));
    await pshot(t, 'cancelled_marks_readonly_banner');
    await backTwice(t);
  });
  await step(t, '5b draft: badge in the list, no marks entry in detail', () async {
    await t.tap(find.byKey(const Key('chip_drafts')));
    await settle(t, 900);
    final note = find.byKey(ValueKey('asm_draft_note_${pid('ASM_draft')}'));
    await waitFor(t, note);
    expectTrue('draft note in the list tile', note.evaluate().isNotEmpty);
    expectTrue('DRAFT tag on the screen', find.text('DRAFT').evaluate().isNotEmpty);
    await pshot(t, 'drafts_list_badge');
    await t.tap(find.byKey(ValueKey('asm_${pid('ASM_draft')}')));
    await waitFor(t, find.byKey(const ValueKey('asm_subject_Mathematics')));
    await settle(t, 1200);
    expectTrue('detail has no Enter marks / View marks', find.byKey(const Key('asm_marks_Mathematics')).evaluate().isEmpty && find.byKey(const Key('asm_view_Mathematics')).evaluate().isEmpty);
    expectTrue('detail explains drafts take no marks', find.byKey(const Key('asm_draft_Mathematics')).evaluate().isNotEmpty);
    await pshot(t, 'draft_detail_no_marks_entry');
    await leaveScreen(t);
    await settle(t, 800);
  });
  await step(t, '5a published WHILE the grid is open: save -> server 403, grid locks, typed value kept', () async {
    await openAssessment(t, 'ASM_publish_open');
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_save_button')));
    await waitFor(t, idKeyed('marks_field_'));
    await settle(t, 1200);
    await t.enterText(firstMarkField, '25');
    await settle(t, 500);
    await dbAction(t, 'publish_open');
    await t.tap(find.byKey(const Key('marks_save_button')));
    await waitFor(t, find.byKey(const Key('marks_confirm_save')));
    await settle(t, 1500);
    await t.tap(find.byKey(const Key('marks_confirm_save')));
    await waitFor(t, find.byKey(const Key('marks_lock_banner')), seconds: 20);
    await settle(t, 1500);
    await t.ensureVisible(find.byKey(const Key('marks_lock_banner'))); // NOT a pull-down: a pull-to-refresh with unsaved marks opens "Leave without saving?"
    await settle(t, 600);
    result('server 403 text shown (save error banner)', find.textContaining('published (or the assessment is cancelled)').evaluate().isNotEmpty);
    expectTrue('grid locked: save button gone', find.byKey(const Key('marks_save_button')).evaluate().isEmpty);
    expectTrue('first field disabled now', !fieldEnabled(t, firstMarkField));
    expectEq('typed value kept', fieldText(t, firstMarkField), '25');
    await pshot(t, 'publish_while_open_403_locked_value_kept');
    await realWait(t, 3);
    await dbAction(t, 'check_marks');
    await dbAction(t, 'unpublish_open');
    await backTwice(t);
  });
  await step(t, '5d stale total lowered in the DB while the grid is open -> 400 -> header and per-row max refresh', () async {
    await openAssessment(t, 'ASM_stale_total');
    await t.tap(find.byKey(const Key('asm_marks_Mathematics')));
    await waitFor(t, find.byKey(const Key('marks_save_button')));
    await waitFor(t, idKeyed('marks_field_'));
    await settle(t, 1200);
    expectTrue('header says out of 50 before', hasText('out of 50'));
    await t.enterText(firstMarkField, '35');
    await settle(t, 500);
    await pshot(t, 'stale_total_before_header_out_of_50');
    await dbAction(t, 'lower_total');
    await t.tap(find.byKey(const Key('marks_save_button')));
    await waitFor(t, find.byKey(const Key('marks_confirm_save')));
    await settle(t, 1500);
    await t.tap(find.byKey(const Key('marks_confirm_save')));
    await waitFor(t, find.byKey(const Key('marks_save_error')), seconds: 20);
    await settle(t, 2500);
    await t.scrollUntilVisible(find.textContaining('out of 20'), -150, scrollable: find.byType(Scrollable).last, maxScrolls: 8);
    await settle(t, 600);
    result('server 400 text', find.textContaining('Marks must be between 0 and 20').evaluate().isNotEmpty);
    expectTrue('header refreshed to out of 20', hasText('out of 20'));
    expectTrue('per-row max refreshed to /20', find.textContaining('/20').evaluate().isNotEmpty);
    expectTrue('row flagged (35 > 20)', find.byKey(ValueKey('marks_error_${keyOf(idKeyed('marks_field_').first.evaluate().first).substring(12)}')).evaluate().isNotEmpty);
    expectEq('typed value kept', fieldText(t, firstMarkField), '35');
    await pshot(t, 'stale_total_400_header_row_max_refreshed');
    await dbAction(t, 'check_marks');
    await backTwice(t);
  });
  await step(t, '5a quiz grading on a PUBLISHED assessment locks; then publish while an attempt is open', () async {
    await toTop(t);
    if (find.byKey(const Key('asm_quiz_card')).evaluate().isEmpty) await toAssessmentsList(t);
    await t.tap(find.byKey(const Key('asm_quiz_card')));
    await waitFor(t, find.byKey(ValueKey('qa_${pid('QA_published')}')));
    await settle(t, 1200);
    await pshot(t, 'quiz_attempts_list');
    await t.tap(find.byKey(ValueKey('qa_${pid('QA_published')}')));
    await waitFor(t, find.byKey(const Key('qa_lock_banner')), seconds: 20);
    await settle(t, 1200);
    expectTrue('no save button on the published quiz attempt', find.byKey(const Key('qa_submit')).evaluate().isEmpty);
    result('quiz lock banner', textOf(t, find.descendant(of: find.byKey(const Key('qa_lock_banner')), matching: find.byType(Text)).first));
    await pshot(t, 'quiz_published_attempt_locked');
    await leaveScreen(t);
    await waitFor(t, find.byKey(ValueKey('qa_${pid('QA_open')}')));
    await t.tap(find.byKey(ValueKey('qa_${pid('QA_open')}')));
    await waitFor(t, find.byKey(const Key('qa_submit')));
    await settle(t, 1200);
    final qm = keyPrefix('qa_mark_').evaluate().where((e) => !keyOf(e).startsWith('qa_mark_error')).toList();
    result('manual-grade inputs', qm.length);
    for (final e in qm) {
      await t.enterText(find.byKey(e.widget.key!), '1');
    }
    await settle(t, 500);
    await dbAction(t, 'publish_quiz');
    await t.tap(find.byKey(const Key('qa_submit')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await settle(t, 900);
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitFor(t, find.byKey(const Key('qa_lock_banner')), seconds: 20);
    await settle(t, 1200);
    expectTrue('save button gone after the 403', find.byKey(const Key('qa_submit')).evaluate().isEmpty);
    await pshot(t, 'quiz_publish_while_open_403_locked');
    await dbAction(t, 'check_marks');
    await dbAction(t, 'unpublish_quiz');
    await leaveToShell(t);
  });
  await step(t, '5c homework attachment: real upload -> 503 -> Upload unavailable + Continue without attachment', () async {
    await openClassesModule(t, 'homework');
    await waitFor(t, find.byKey(const Key('hw_new_fab')));
    await t.tap(find.byKey(const Key('hw_new_fab')));
    await waitFor(t, find.byKey(const Key('hw_save_draft')));
    await settle(t, 1000);
    await t.tap(find.byKey(const ValueKey('class_chip_0')));
    await settle(t, 1800);
    await t.enterText(find.byKey(const Key('hw_title_field')), 'P7C upload test');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await settle(t, 600);
    hwPicker.next = [PickedAttachment(name: 'P7C worksheet.pdf', path: await tempFile('P7C worksheet.pdf', 20 * 1024), size: 20 * 1024)];
    await t.tap(find.byKey(const Key('hw_add_attachment')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('hw_pick_files')));
    await settle(t, 3500);
    await t.scrollUntilVisible(find.textContaining('Continue without attachment'), 200, scrollable: find.byType(Scrollable).last, maxScrolls: 10);
    await settle(t, 500);
    expectTrue('"Upload unavailable" title shown', find.text('Upload unavailable').evaluate().isNotEmpty);
    expectTrue('server text shown', hasText('File uploads are not available on this server'));
    expectTrue('no Retry button for it', find.textContaining('Retry').evaluate().isEmpty);
    await pshot(t, 'homework_upload_unavailable_503');
    await t.tap(find.textContaining('Continue without attachment'));
    await settle(t, 900);
    expectTrue('failed attachment removed', find.text('Upload unavailable').evaluate().isEmpty);
    await pshot(t, 'homework_continue_without_attachment');
    await leaveScreen(t);
    await leaveToShell(t);
  });
}

// =============================================================================================================== 5f B5 field hiding on screen
Future<void> b5Scenario(WidgetTester t) async {
  await step(t, 'B login', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
  });
  await step(t, '5f student list + Student 360 render with the reduced payload', () async {
    await openClassesModule(t, 'students');
    await waitFor(t, find.byType(StudentTile));
    await settle(t, 1500);
    await pshot(t, 'student_list');
    await t.tap(find.byType(StudentTile).first);
    await waitFor(t, find.byKey(const Key('student_profile')));
    await settle(t, 2500);
    expectTrue('Student 360 profile card renders', find.byKey(const Key('student_profile')).evaluate().isNotEmpty);
    result('"No guardians on record" on screen', hasText('No guardians on record'));
    result('student_guardians section present', find.byKey(const Key('student_guardians')).evaluate().isNotEmpty);
    result('message-guardian button present', find.byKey(const Key('student_message_guardian')).evaluate().isNotEmpty);
    await pshot(t, 'student360_top');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await settle(t, 800);
    await pshot(t, 'student360_lower');
    await leaveToShell(t);
  });
}

// =============================================================================================================== 3 safeguarding (B with a student, A without)
Future<void> concern(WidgetTester t, {required bool withStudent, required String who}) async {
  await openFromMore(t, 'Raise a concern', find.byKey(const Key('sg_notice')));
  await pshot(t, '${who}_form_notice');
  if (withStudent) {
    await t.tap(find.byKey(const Key('sg_student_picker')));
    await waitFor(t, find.text('Only students of your classes are listed.'));
    await settle(t, 1800);
    await t.tap(find.byType(StudentTile).first);
    await settle(t, 1000);
  }
  await t.tap(find.byKey(const Key('sg_type_bullying')));
  await t.tap(find.byKey(const Key('sg_sev_high')));
  await t.enterText(find.byKey(const Key('sg_title')), 'P7C-SG-DUMMY summary from $who');
  await t.enterText(find.byKey(const Key('sg_description')), 'P7C-SG-DUMMY description typed by $who, not a real concern.');
  await t.enterText(find.byKey(const Key('sg_actions')), 'P7C-SG-DUMMY action');
  await settle(t, 600);
  await pshot(t, '${who}_form_filled_dummy');
  await t.tap(find.byKey(const Key('sg_submit')));
  await waitFor(t, find.text('Send this concern?'));
  await settle(t, 600);
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.byKey(const Key('sg_sent_title')), seconds: 20);
  await settle(t, 1200);
  expectTrue('"Report sent" shown', hasText('Report sent'));
  result('case reference shown', find.byKey(const Key('sg_reference')).evaluate().isNotEmpty);
  await pshot(t, '${who}_report_sent');
  await t.tap(find.byKey(const Key('sg_done')));
  await settle(t, 1000);
}

Future<void> safeScenario(WidgetTester t) async {
  await step(t, 'B login + concern about a student', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
    await concern(t, withStudent: true, who: 'B');
    await dbAction(t, 'check_sg');
  });
  await step(t, 'sign out; A login + concern without a student', () async {
    await leaveToShell(t);
    await signOutViaUi(t);
    await signIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await concern(t, withStudent: false, who: 'A');
    await dbAction(t, 'check_sg');
    await dbAction(t, 'check_sg_privacy');
    await dbAction(t, 'check_app_container');
  });
}

// =============================================================================================================== 4 profile + avatar
Future<void> profileScenario(WidgetTester t) async {
  final picker = _P();
  AvatarPickers.current = picker;
  await step(t, 'A login + profile details', () async {
    await bootAndSignIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Profile', find.byKey(const Key('profile_name')));
    await settle(t, 1500);
    result('profile shows name/email/school/campus/department/designation/employee id', [for (final k in ['profile_name', 'profile_email', 'profile_campus', 'profile_department', 'profile_designation']) find.byKey(Key(k)).evaluate().isNotEmpty].join(','));
    expectTrue('email row present', find.byKey(const Key('profile_email')).evaluate().isNotEmpty);
    await pshot(t, 'profile_details');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await settle(t, 800);
    await pshot(t, 'profile_teaching_settings');
    await t.drag(find.byType(Scrollable).last, const Offset(0, 900));
    await settle(t, 600);
  });
  await step(t, 'client-side refusals: > 10 MB and a wrong type (nothing is sent)', () async {
    picker.next = PickedAvatar(path: await tempFile('big.png', 11 * 1024 * 1024), name: 'big.png', size: 11 * 1024 * 1024);
    await t.tap(find.byKey(const Key('avatar_gallery')));
    await waitFor(t, find.byKey(const Key('avatar_outcome_rejected')));
    await settle(t, 800);
    await pshot(t, 'avatar_refused_over_10mb');
    picker.next = PickedAvatar(path: await tempFile('x.gif', 2048), name: 'x.gif', size: 2048);
    await t.tap(find.byKey(const Key('avatar_gallery')));
    await settle(t, 1200);
    expectTrue('wrong type refused', find.byKey(const Key('avatar_outcome_rejected')).evaluate().isNotEmpty);
    await pshot(t, 'avatar_refused_wrong_type');
    await dbAction(t, 'mark_after_refusals');
  });
  await step(t, 'real upload with no S3 -> 503 -> Upload unavailable, photo buttons disabled', () async {
    final png = await tempFile('me.png', 0);
    await File(png).writeAsBytes(smallPng());
    picker.next = PickedAvatar(path: png, name: 'me.png', size: await File(png).length());
    await t.tap(find.byKey(const Key('avatar_gallery')));
    await waitFor(t, find.byKey(const Key('avatar_outcome_unavailable')), seconds: 20);
    await settle(t, 1000);
    expectTrue('Upload unavailable shown', hasText('Upload unavailable'));
    result('app message (not the raw server text)', hasText('Photo upload is not available on this server right now'));
    final g = t.widget(find.byKey(const Key('avatar_gallery')));
    final c = t.widget(find.byKey(const Key('avatar_camera')));
    result('gallery/camera buttons disabled', '${_disabled(g)}/${_disabled(c)}');
    await pshot(t, 'avatar_upload_unavailable_503');
    await dbAction(t, 'check_user_a_avatar');
  });
}

bool _disabled(Widget w) {
  if (w is ButtonStyleButton) return w.onPressed == null;
  if (w is InkWell) return w.onTap == null;
  return false;
}

class _P implements AvatarPicker {
  PickedAvatar? next;
  @override
  Future<PickedAvatar?> pick(AvatarSource source) async => next;
}

// =============================================================================================================== 4 help / about / delete account
Future<void> helpScenario(WidgetTester t) async {
  await step(t, 'A login + help list, article, unsafe markup, search', () async {
    await bootAndSignIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await settle(t, 2500);
    await openFromMore(t, 'Help', find.byKey(const Key('help_search')));
    await waitFor(t, find.text('Dashboard'));
    await settle(t, 800);
    await pshot(t, 'help_list_seeded_kb');
    final art1 = find.byKey(const ValueKey('help_p7c/getting-started'));
    await t.scrollUntilVisible(art1, 300, scrollable: find.byType(Scrollable).first, maxScrolls: 25);
    await settle(t, 500);
    await pshot(t, 'help_list_dummy_module_p7c');
    await t.tap(art1);
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    await pshot(t, 'help_article_markdown');
    await leaveScreen(t);
    final art2 = find.byKey(const ValueKey('help_p7c/adversarial'));
    await t.scrollUntilVisible(art2, 300, scrollable: find.byType(Scrollable).first, maxScrolls: 25);
    await t.tap(art2);
    await waitFor(t, find.byKey(const Key('help_article_title')));
    await settle(t, 1200);
    expectTrue('script/iframe/style source text not rendered as markup (no <script on screen)', !hasText('<script') && !hasText('<iframe'));
    result('visible text contains alert(', hasText('alert('));
    await pshot(t, 'help_article_unsafe_markup_inert');
    await leaveScreen(t);
    await toTop(t);
    await t.enterText(find.byKey(const Key('help_search')), 'leave');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t, 2500);
    result('search result shows the leave article', hasText('P7C How to apply for leave'));
    await pshot(t, 'help_search_leave');
    await t.tap(find.byKey(const Key('help_search_clear')));
    await settle(t, 600);
    await leaveToShell(t);
  });
  await step(t, 'about', () async {
    await openFromMore(t, 'About', find.byKey(const Key('about_name')));
    await settle(t, 1500);
    result('about screen texts', allTexts().where((x) => x.trim().isNotEmpty).join(' | '));
    await pshot(t, 'about');
    await leaveToShell(t);
  });
  await step(t, 'delete-account request: type-to-confirm -> real POST -> still signed in; second request', () async {
    await openFromMore(t, 'Delete account', find.byKey(const Key('delete_explainer')));
    await pshot(t, 'delete_explanation');
    await t.enterText(find.byKey(const Key('delete_reason')), 'P7C dummy reason');
    await t.enterText(find.byKey(const Key('delete_confirm_field')), 'delete');
    await settle(t, 800);
    await pshot(t, 'delete_typed_confirmation');
    await t.tap(find.byKey(const Key('delete_submit')));
    await waitFor(t, find.byKey(const Key('delete_done_title')), seconds: 20);
    await settle(t, 1200);
    result('done screen texts', allTexts().where((x) => x.trim().isNotEmpty).join(' | '));
    await pshot(t, 'delete_request_sent_still_signed_in');
    await dbAction(t, 'check_delete');
    await t.tap(find.byKey(const Key('delete_done')));
    await settle(t, 1200);
    expectTrue('still signed in (bottom nav visible)', find.byType(BottomNavigationBar).evaluate().isNotEmpty);
    await openFromMore(t, 'Delete account', find.byKey(const Key('delete_explainer')));
    await t.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
    await settle(t, 500);
    await t.tap(find.byKey(const Key('delete_submit')));
    await waitFor(t, find.byKey(const Key('delete_done_title')), seconds: 20);
    await settle(t, 1200);
    expectTrue('already-requested message', hasText('already'));
    await pshot(t, 'delete_already_requested');
    await dbAction(t, 'check_delete');
    await t.tap(find.byKey(const Key('delete_done')));
    await settle(t, 800);
    await leaveToShell(t);
  });
}

// =============================================================================================================== 1+2 calendar, circulars, events (B; A for the individual circular)
Finder dayCell(int d, {bool last = false}) {
  final f = find.descendant(of: find.byKey(const Key('cal_grid')), matching: find.text('$d'));
  return last ? f.last : f.first;
}

Future<void> pickDay(WidgetTester t, int d, {bool last = false}) async {
  await t.tap(dayCell(d, last: last));
  await settle(t, 900);
}

Finder circ(String k) => find.byKey(ValueKey('circular_${pid(k)}'));
Finder ev(String k) => find.byKey(ValueKey('event_${pid(k)}'));

Future<void> calScenario(WidgetTester t) async {
  await step(t, 'B login + calendar month', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 2500);
    await openFromMore(t, 'School calendar', find.byKey(const Key('cal_grid')));
    await waitFor(t, find.byKey(const Key('day_heading')));
    await settle(t, 1500);
    expectTrue('no Fee Due / outstanding text anywhere on screen', !hasText('Fee Due') && !hasText('outstanding') && !hasText('Total outstanding'));
    await pshot(t, 'month_today_legend');
  });
  await step(t, 'days: every type, colours, all-day + multi-day + timed (PKT device)', () async {
    for (final d in [10, 12, 14, 15, 16, 17, 18, 21, 22]) {
      await pickDay(t, d);
      result('day $d heading', textOf(t, find.byKey(const Key('day_heading'))));
      result('day $d entries (P7C)', [for (final x in allTexts()) if (x.startsWith('P7C')) x].join(' | '));
      await pshot(t, 'day_$d');
    }
  });
  await step(t, 'all-day stored as UTC midnight shows on that day; the PKT-midnight PROBE row; fee day 25; month end span', () async {
    await pickDay(t, 23);
    result('day 23 (probe stored 23 Oct 19:00 UTC = 24 Oct 00:00 PKT)', [for (final x in allTexts()) if (x.startsWith('P7C')) x].join(' | '));
    await pickDay(t, 24);
    result('day 24 entries', [for (final x in allTexts()) if (x.startsWith('P7C')) x].join(' | '));
    await pshot(t, 'day_24_probe');
    await pickDay(t, 25);
    result('day 25 (fee-due rows exist in the API) shows', hasText('Fee') || hasText('outstanding') ? 'FEE TEXT VISIBLE' : 'no fee text');
    await pshot(t, 'day_25_fee_due_day_nothing_shown');
    for (final d in [28, 30, 31]) {
      await pickDay(t, d, last: d != 31 ? true : false);
      result('day $d (month-end span 28th..2nd) entries', [for (final x in allTexts()) if (x.startsWith('P7C')) x].join(' | '));
    }
    await pshot(t, 'day_31_month_end_span');
    await t.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await settle(t, 2500);
    await pickDay(t, 2);
    result('Nov 2 entries (span end)', [for (final x in allTexts()) if (x.startsWith('P7C')) x].join(' | '));
    await pshot(t, 'next_month_nov_2_span_end');
    await t.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await settle(t, 2000);
  });
  await step(t, 'agenda', () async {
    await t.tap(find.text('Agenda'));
    await settle(t, 1600);
    await pshot(t, 'agenda_top');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await settle(t, 700);
    await pshot(t, 'agenda_lower');
    await t.tap(find.text('Month'));
    await settle(t, 800);
  });
  await step(t, 'circulars: only published staff-addressed; ack; link dialog', () async {
    await t.tap(find.byKey(const Key('tab_circulars')));
    await waitFor(t, circ('C1_published_staff'));
    await settle(t, 1500);
    for (final k in ['C1_published_staff', 'C2_ack_urgent', 'C7_my_campus', 'C8_individual_B', 'C9_staff_parent_grade']) result('visible for B $k', circ(k).evaluate().isNotEmpty);
    for (final k in ['C3_draft_staff', 'C4_scheduled_staff', 'C5_parent_only', 'C6_other_campus']) expectTrue('hidden $k', circ(k).evaluate().isEmpty);
    await pshot(t, 'circulars_list_B');
    await t.tap(circ('C2_ack_urgent'));
    await waitFor(t, find.byKey(const Key('circular_sheet')));
    await settle(t, 1000);
    await pshot(t, 'circular_detail_ack_button');
    await t.tap(find.byKey(const ValueKey('circular_link_https://example.test/evac')));
    await waitFor(t, find.text('Open this link?'));
    await settle(t, 600);
    await pshot(t, 'circular_link_confirm_dialog');
    await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('circular_ack_button')));
    await waitFor(t, find.byKey(const Key('circular_ack_done')), seconds: 20);
    await settle(t, 1000);
    await pshot(t, 'circular_acknowledged');
    await dbAction(t, 'check_ack');
    await t.tapAt(const Offset(20, 80));
    await settle(t, 800);
    await pshot(t, 'circulars_after_ack');
    await t.tap(find.byKey(const Key('tab_calendar')));
    await settle(t, 600);
    await leaveToShell(t);
  });
  await step(t, 'events: list + detail', () async {
    await openFromMore(t, 'Events', find.byKey(ValueKey('event_${pid('E1_public_published')}')));
    await settle(t, 1200);
    for (final k in ['E1_public_published', 'E2_internal_published', 'E6_cancelled_public', 'E7_completed_past', 'E8_no_sessions']) result('visible $k', ev(k).evaluate().isNotEmpty);
    for (final k in ['E3_draft_public', 'E4_private_published', 'E5_unlisted_published']) expectTrue('hidden $k', ev(k).evaluate().isEmpty);
    await pshot(t, 'events_list');
    await t.tap(ev('E1_public_published'));
    await waitFor(t, find.byKey(const Key('event_title')));
    await settle(t, 1500);
    expectTrue('no promo code / ticket price / ticket type on screen', !hasText('P7CPROMO20') && !hasText('P7C VIP') && !hasText('P7C General') && !hasText('5000') && !hasText('1500'));
    await pshot(t, 'event_detail_no_ticket_promo');
    await leaveToShell(t);
  });
  await step(t, 'sign out; A login: individual circular C8 not shown', () async {
    await signOutViaUi(t);
    await signIn(t, e2eTeacherEmail, e2eTeacherPassword);
    await openFromMore(t, 'School calendar', find.byKey(const Key('cal_grid')));
    await t.tap(find.byKey(const Key('tab_circulars')));
    await waitFor(t, circ('C1_published_staff'));
    await settle(t, 1500);
    expectTrue('A does not see C8 (B only)', circ('C8_individual_B').evaluate().isEmpty);
    result('A sees C1/C2/C7/C9', [for (final k in ['C1_published_staff', 'C2_ack_urgent', 'C7_my_campus', 'C9_staff_parent_grade']) circ(k).evaluate().isNotEmpty].join(','));
    await pshot(t, 'circulars_list_A');
    await leaveToShell(t);
  });
}

// =============================================================================================================== 5e hung server (the logging proxy answers nothing)
Future<void> hungScenario(WidgetTester t) async {
  await step(t, 'B login, Home with data', () async {
    await bootAndSignIn(t, e2eClassEmail, e2eClassPassword);
    await settle(t, 4000);
    expectTrue('Home greeting visible', find.byKey(const Key('greeting')).evaluate().isNotEmpty);
    await pshot(t, 'home_before_hang');
  });
  await step(t, 'pull-to-refresh with a hung server: errors within ~20 s, old data stays, Retry works after release', () async {
    await dbAction(t, 'proxy_hang');
    final sw = Stopwatch()..start();
    await t.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await t.pump(const Duration(milliseconds: 600));
    var errAt = -1.0;
    for (var i = 0; i < 40; i++) {
      await realWait(t, 1);
      if (find.byKey(const Key('section_error')).evaluate().isNotEmpty || hasText('taking too long')) {
        errAt = sw.elapsedMilliseconds / 1000;
        break;
      }
    }
    result('seconds from the pull until the first error text appeared (cap 40)', errAt < 0 ? 'NEVER' : errAt.toStringAsFixed(1));
    // let the remaining sections end too, and see when the spinner stops
    var settledAt = -1.0;
    for (var i = 0; i < 40; i++) {
      if (find.byType(RefreshProgressIndicator).evaluate().isEmpty) {
        settledAt = sw.elapsedMilliseconds / 1000;
        break;
      }
      await realWait(t, 1);
    }
    result('seconds until the refresh spinner stopped', settledAt < 0 ? 'NEVER' : settledAt.toStringAsFixed(1));
    result('error banners/sections on Home', find.byKey(const Key('section_error')).evaluate().length);
    expectTrue('old data stays visible (greeting still there)', find.byKey(const Key('greeting')).evaluate().isNotEmpty);
    await pshot(t, 'home_hung_errors_old_data_kept');
    await dbAction(t, 'proxy_forward');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await settle(t, 600);
    final retry = find.text('Retry');
    if (retry.evaluate().isNotEmpty) {
      await t.tap(retry.first);
      await realWait(t, 4);
    } else {
      await t.drag(find.byType(Scrollable).first, const Offset(0, 500));
      await realWait(t, 5);
    }
    await settle(t, 1500);
    result('error sections after the proxy was released + Retry', find.byKey(const Key('section_error')).evaluate().length);
    await pshot(t, 'home_after_release_retry');
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = [e2eBaseUrl, e2eTeacherEmail, e2eTeacherPassword, e2eClassEmail, e2eClassPassword, p7Scenario, p7Ids].every((e) => e.isNotEmpty);
  if (!configured) print('SKIPPED p7c_local_test: pass --dart-define for API_BASE_URL, LOCAL_* credentials, P7_SCENARIO, P7_IDS (see tool/dev/capture_p7c.sh).');
  testWidgets('Phase 7 part 2 against the LOCAL backend: $p7Scenario', skip: !configured, timeout: const Timeout(Duration(minutes: 14)), (t) async {
    switch (p7Scenario) {
      case 'marks':
        await marksScenario(t);
      case 'b5':
        await b5Scenario(t);
      case 'safe':
        await safeScenario(t);
      case 'profile':
        await profileScenario(t);
      case 'help':
        await helpScenario(t);
      case 'cal':
        await calScenario(t);
      case 'hung':
        await hungScenario(t);
      default:
        throw TestFailure('unknown P7_SCENARIO $p7Scenario');
    }
    print('P7_DONE scenario=$p7Scenario failures=${e2eFailures.length}');
    for (final f in e2eFailures) print('FAILED_STEP $f');
    expect(e2eFailures, isEmpty);
  });
}
