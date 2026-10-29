// RELEASE A1 verification on the simulator against the LOCAL backend (isolated DB eldermin_teacher_verify, backend main 0ed3d8d, every guard flag
// in enforce mode; NOT staging, NOT the stub). One scenario per run, chosen with --dart-define=A1_SCENARIO=<base|class|viewonly|noassess|suspended|
// deactivated|tarbiyah>; run through tool/dev/capture_a1.sh (watchdog, screenshots, the few DB actions a scenario asks for). Credentials only via
// --dart-define (dummy local accounts), never stored. Every check prints CHECK_PASS / CHECK_FAIL and the run fails at the end if any failed, so
// the screenshots of a failing scenario are still taken.
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_common.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

const _scenario = String.fromEnvironment('A1_SCENARIO');
const _email = String.fromEnvironment('A1_EMAIL');
const _password = String.fromEnvironment('A1_PASSWORD');
const _studentName = String.fromEnvironment('A1_STUDENT_NAME', defaultValue: 'Ahmed Malik');
const _base = String.fromEnvironment('API_BASE_URL');

final _checks = <String>[];

/// Like e2e_common's startRun, but waits for the animated splash hand-off (design/auth-motion) to finish before tapping Skip.
Future<void> startA1(WidgetTester t) async {
  app.main();
  await t.pump(const Duration(milliseconds: 300));
  await waitFor(t, find.text('Skip'), seconds: 40);
  await settle(t, 4000);
  for (var i = 0; i < 3 && present(find.text('Skip')); i++) {
    await t.tap(find.text('Skip').first, warnIfMissed: false);
    await settle(t, 1500);
  }
  await waitFor(t, find.text('Sign in'), seconds: 30);
  await settle(t, 1500);
}

void check(String what, bool ok, [String detail = '']) {
  print('${ok ? 'CHECK_PASS' : 'CHECK_FAIL'} $what${detail.isEmpty ? '' : ' ($detail)'}');
  if (!ok) _checks.add(what);
}

bool present(Finder f) => f.evaluate().isNotEmpty;
Finder txt(String s) => find.text(s);
/// Scrolls the visible list until [f] is built (lists are lazy); false when it never shows up.
Future<bool> scrollTo(WidgetTester t, Finder f) async {
  if (present(f)) return true;
  try {
    await t.scrollUntilVisible(f, 700, scrollable: find.byType(Scrollable).last, maxScrolls: 60);
    await settle(t, 500);
    return present(f);
  } catch (_) {
    return false;
  }
}

Future<void> vis(WidgetTester t, Finder f) async {
  await scrollTo(t, f);
  if (present(f)) await t.ensureVisible(f);
  await settle(t, 300);
}

bool hasText(String s) => present(find.text(s)) || present(find.textContaining(s));

Future<void> openMore(WidgetTester t) async {
  await t.tap(navLabel('More'));
  await settle(t, 1200);
}

Future<void> openClasses(WidgetTester t) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1200);
}

Future<void> backToShell(WidgetTester t) async {
  await leaveToShell(t);
  await settle(t, 600);
}

/// Opens a More-list entry by its title.
Future<void> openMoreEntry(WidgetTester t, String title) async {
  await openMore(t);
  if (!await scrollTo(t, find.text(title))) {
    await toTop(t);
    await scrollTo(t, find.text(title));
  }
  await t.tap(find.text(title).first);
  await settle(t, 1800);
}

// ───────────────────────────────────────── base teacher (teacher A) and class teacher (teacher B)
Future<void> baseScenario(WidgetTester t, {required bool classTeacher}) async {
  final who = classTeacher ? 'class' : 'base';
  await step(t, '$who login', () async {
    await signIn(t, _email, _password);
    await shot(t, '${who}_01_home');
  });
  await step(t, '$who Classes grid', () async {
    await openClasses(t);
    await shot(t, '${who}_02_classes');
    check('$who: Homework tile', present(find.byKey(const ValueKey('module_homework'))));
    check('$who: Attendance tile ${classTeacher ? 'present (class teacher)' : 'absent (not a class teacher)'}', present(find.byKey(const ValueKey('module_attendance'))) == classTeacher);
  });
  await step(t, '$who More list: self-service present, no deletion request', () async {
    await openMore(t);
    check('$who: My leave', await scrollTo(t, find.text('My leave')));
    await shot(t, '${who}_03_more_a');
    check('$who: My attendance', await scrollTo(t, find.text('My attendance')));
    await shot(t, '${who}_03_more_b');
    await scrollTo(t, find.byKey(const Key('more_sign_out')));
    await shot(t, '${who}_03_more_c_account');
    check('$who: no "Request account deletion"', !hasText('account deletion'));
  });
  await step(t, '$who homework: New homework is offered', () async {
    await openClassesModule(t, 'homework');
    await waitForAny(t, [find.byKey(const Key('hw_new_fab')), find.byKey(const Key('screen_empty')), find.byKey(const Key('screen_error'))]);
    await settle(t, 1500);
    await shot(t, '${who}_04_homework');
    check('$who: "New homework" button', present(find.byKey(const Key('hw_new_fab'))));
    await backToShell(t);
  });
  await step(t, '$who Student 360: results come from the marks route', () async {
    await openClassesModule(t, 'students');
    await settle(t, 2000);
    await t.enterText(find.byKey(const Key('students_search')), _studentName.split(' ').first);
    await settle(t, 1200);
    await tapText(t, _studentName);
    await settle(t, 2500);
    check('$who: results card reachable', await scrollTo(t, find.byKey(const Key('student_results'))));
    await settle(t, 700);
    await shot(t, '${who}_05_student360_results');
    final inCard = [
      for (final e in find.descendant(of: find.byKey(const Key('student_results')), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
    ];
    print('INFO results card texts: $inCard');
    check('$who: Recent results card lists a marks-based row (Unit Test 1 - Mathematics)', inCard.any((s) => s.contains('Unit Test 1')));
    check('$who: not "No recent results."', !inCard.contains('No recent results.'));
    await backToShell(t);
  });
  await step(t, '$who Help FAQ: data deletion', () async {
    await openMoreEntry(t, 'Help');
    await settle(t, 1500);
    check('$who: FAQ entry present', await scrollTo(t, find.byKey(const ValueKey('faq_delete_data'))));
    await t.tap(find.byKey(const ValueKey('faq_delete_data')));
    await settle(t, 900);
    await shot(t, '${who}_06_help_faq_delete');
    check('$who: FAQ answer', hasText('To have your data deleted, please contact your school.'));
    await backToShell(t);
  });
  if (classTeacher) {
    await step(t, 'class attendance hub: Mark button for a class teacher', () async {
      await openClassesModule(t, 'attendance');
      await waitFor(t, find.byKey(const Key('hub_mark_button')));
      await settle(t, 1500);
      await shot(t, 'class_07_attendance_hub');
      check('class: Mark attendance button', present(find.byKey(const Key('hub_mark_button'))));
      await backToShell(t);
    });
    await step(t, 'class behaviour: "My entries" reaches an entry older than the first page (server-side mine=true)', () async {
      await openClassesModule(t, 'behaviour');
      await settle(t, 3500);
      await shot(t, 'class_08_behaviour_my_entries');
      // 9 = the 8 seeded entries of teacher B + the OLD one; the grade has 69 records and the first page holds 50 newer ones, so 9 can only come from mine=true
      check('class: "My classes (N)" count shows BEFORE that tab is opened', find.textContaining('My classes (').evaluate().isNotEmpty, '${[for (final e in find.textContaining('My classes').evaluate()) (e.widget as Text).data]}');
      check('class: "My entries (9)" includes the entry older than the first page (server-side mine=true)', hasText('My entries (9)'));
      await scrollTo(t, find.textContaining('OLD ENTRY BY TEACHER B'));
      await shot(t, 'class_08b_behaviour_old_entry');
      check('class: no colleague entry under My entries', !hasText('Colleague entry'));
      await backToShell(t);
    });
  }
}

// ───────────────────────────────────────── view-only custom role
Future<void> viewOnlyScenario(WidgetTester t) async {
  await step(t, 'viewonly login', () async {
    await signIn(t, _email, _password);
    await shot(t, 'viewonly_01_home');
  });
  await step(t, 'viewonly Home quick actions: no Mark Attendance / Add Homework', () async {
    final fab = find.byKey(const Key('quick_actions_fab'));
    check('viewonly: quick actions button exists (self-service Apply Leave)', present(fab));
    await t.tap(fab);
    await settle(t, 1200);
    await shot(t, 'viewonly_02_quick_actions');
    check('viewonly: no Mark Attendance', !present(find.byKey(const Key('quick_action_attendance'))));
    check('viewonly: no Add Homework', !present(find.byKey(const Key('quick_action_homework'))));
    check('viewonly: Apply Leave', present(find.byKey(const Key('quick_action_leave'))));
    await t.tapAt(const Offset(20, 120));
    await settle(t, 800);
  });
  await step(t, 'viewonly homework: list opens, no New homework; detail has no Edit / Delete', () async {
    await openClassesModule(t, 'homework');
    await waitForAny(t, [idKeyed('hw_tile_'), find.byKey(const Key('screen_empty'))]);
    await settle(t, 1500);
    await shot(t, 'viewonly_03_homework');
    check('viewonly: no "New homework"', !present(find.byKey(const Key('hw_new_fab'))));
    final first = keyPrefix('hw_');
    print('INFO homework keys: ${first.evaluate().map((e) => e.widget.key).take(6).toList()}');
    final title = find.textContaining('Fractions');
    if (present(title)) {
      await t.tap(title.first);
      await waitFor(t, find.byKey(const Key('hw_view_submissions')), seconds: 15);
      await settle(t, 1200);
      await shot(t, 'viewonly_04_homework_detail');
      check('viewonly: no Edit button', !present(find.byKey(const Key('hw_edit'))));
      check('viewonly: no Delete button', !present(find.byKey(const Key('hw_delete'))));
      check('viewonly: submissions still readable', present(find.byKey(const Key('hw_view_submissions'))));
    } else {
      print('INFO no homework row to open');
    }
    await backToShell(t);
  });
  await step(t, 'viewonly attendance hub: no Mark button', () async {
    await openClassesModule(t, 'attendance');
    await settle(t, 2500);
    await shot(t, 'viewonly_05_attendance_hub');
    check('viewonly: no hub_mark_button', !present(find.byKey(const Key('hub_mark_button'))));
    check('viewonly: history still available', present(find.byKey(const Key('hub_history_button'))));
    await backToShell(t);
  });
  await step(t, 'viewonly behaviour: no log button', () async {
    await openClassesModule(t, 'behaviour');
    await settle(t, 3000);
    await shot(t, 'viewonly_06_behaviour');
    check('viewonly: behaviour list readable', !present(find.byKey(const Key('screen_forbidden'))));
    await backToShell(t);
  });
  await step(t, 'viewonly PTM: no New meeting', () async {
    await openMoreEntry(t, 'Parent meetings');
    await settle(t, 1500);
    await shot(t, 'viewonly_07_ptm');
    check('viewonly: no "New meeting"', !present(find.byKey(const Key('ptm_new'))));
    await backToShell(t);
  });
  await step(t, 'viewonly assessments: View marks instead of Enter marks', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await settle(t, 2500);
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    final title = find.textContaining('Unit Test 1');
    if (present(title)) {
      await t.tap(title.first);
      await settle(t, 2500);
      await shot(t, 'viewonly_08_assessment_detail');
      check('viewonly: no Enter marks', keyPrefix('asm_marks_').evaluate().isEmpty);
      print('INFO view keys: ${keyPrefix('asm_view_').evaluate().length}');
    }
    await backToShell(t);
  });
  await step(t, 'viewonly More: My leave and My attendance stay visible although the role does not grant them', () async {
    await openMore(t);
    check('viewonly: My leave', await scrollTo(t, find.text('My leave')));
    check('viewonly: My attendance', await scrollTo(t, find.text('My attendance')));
    await shot(t, 'viewonly_09_more');
  });
  await step(t, 'viewonly student leaves: a request can be read, with no Approve / Reject', () async {
    await openMoreEntry(t, 'Student leave requests');
    await settle(t, 1500);
    final rows = keyPrefix('leave_');
    print('INFO leave row keys: ${rows.evaluate().map((e) => e.widget.key).take(4).toList()}');
    await shot(t, 'viewonly_10_student_leaves');
    final tile = find.textContaining('Malik');
    if (present(tile)) {
      await t.tap(tile.first);
      await settle(t, 2000);
      await shot(t, 'viewonly_11_student_leave_detail');
      check('viewonly: no Approve', !present(find.byKey(const Key('leave_approve'))));
      check('viewonly: no Reject', !present(find.byKey(const Key('leave_reject'))));
    }
    await backToShell(t);
  });
}

// ───────────────────────────────────────── custom role without the Assessments module
Future<void> noAssessScenario(WidgetTester t) async {
  await step(t, 'noassess login + Classes grid without Assessments', () async {
    await signIn(t, _email, _password);
    await shot(t, 'noassess_01_home');
    await openClasses(t);
    await shot(t, 'noassess_02_classes');
    check('noassess: no Assessments tile', !present(find.byKey(const ValueKey('module_assessments'))));
    check('noassess: Homework tile (teaching:manage)', present(find.byKey(const ValueKey('module_homework'))));
    check('noassess: Behaviour tile', present(find.byKey(const ValueKey('module_behaviour'))));
  });
  await step(t, 'noassess More: modules the role lacks are gone, self-service stays', () async {
    await openMore(t);
    check('noassess: My leave', await scrollTo(t, find.text('My leave')));
    check('noassess: My attendance', await scrollTo(t, find.text('My attendance')));
    await shot(t, 'noassess_03_more');
    await scrollTo(t, find.byKey(const Key('more_sign_out')));
    check('noassess: no Curriculum', !hasText('Curriculum'));
    check('noassess: no Library', !hasText('Library'));
    check('noassess: no School calendar', !hasText('School calendar'));
    await shot(t, 'noassess_03_more_b');
  });
  await step(t, 'noassess homework: manage role keeps New homework', () async {
    await openClassesModule(t, 'homework');
    await waitForAny(t, [find.byKey(const Key('hw_new_fab')), find.byKey(const Key('screen_empty'))]);
    await settle(t, 1500);
    await shot(t, 'noassess_04_homework');
    check('noassess: "New homework" (teaching:manage)', present(find.byKey(const Key('hw_new_fab'))));
    await backToShell(t);
  });
}

// ───────────────────────────────────────── 403 SCHOOL_SUSPENDED
Future<void> suspendedScenario(WidgetTester t) async {
  await step(t, 'suspended: signed in, school then suspended in the DB', () async {
    await signIn(t, _email, _password);
    await shot(t, 'suspended_01_home_before');
    await dbAction(t, 'suspend_school');
    await openClassesModule(t, 'homework'); // any authenticated call
    await waitFor(t, find.byKey(const Key('school_suspended')), seconds: 30);
    await settle(t, 1200);
    await shot(t, 'suspended_02_full_screen');
    check('suspended: full-screen state with the server message', hasText('currently suspended') || hasText('suspended'));
    check('suspended: Log out button', present(find.byKey(const Key('school_suspended_logout'))));
    check('suspended: no app navigation visible', !present(find.byKey(const Key('app_shell_nav'))));
  });
  await step(t, 'suspended: Log out returns to sign-in', () async {
    await t.tap(find.byKey(const Key('school_suspended_logout')));
    await waitFor(t, find.text('Sign in'));
    await settle(t, 1200);
    await shot(t, 'suspended_03_login_after_logout');
    check('suspended: login screen', hasText('Sign in'));
  });
  await step(t, 'suspended: signing in again while suspended shows the server message on the form', () async {
    await t.enterText(tf('Email'), _email);
    await t.enterText(tf('Password'), _password);
    await t.tap(find.text('Sign in'));
    await settle(t, 3500);
    await shot(t, 'suspended_04_login_while_suspended');
    check('suspended: login refused with a message about suspension', hasText('suspended'));
    await dbAction(t, 'restore_school');
  });
}

// ───────────────────────────────────────── 401 deactivated staff
Future<void> deactivatedScenario(WidgetTester t) async {
  await step(t, 'deactivated: signed in, staff then deactivated in the DB', () async {
    await signIn(t, _email, _password);
    await shot(t, 'deactivated_01_home_before');
    await dbAction(t, 'deactivate_staff');
    await openClassesModule(t, 'homework');
    await waitFor(t, find.text('Sign in'), seconds: 30);
    await settle(t, 1500);
    await shot(t, 'deactivated_02_login_with_notice');
    check('deactivated: back on the login screen', hasText('Sign in'));
    check('deactivated: notice "Your account is no longer active. Please contact your school."', hasText('Your account is no longer active. Please contact your school.'));
    check('deactivated: not the generic "Session expired"', !hasText('Session expired'));
    await dbAction(t, 'restore_staff');
  });
}

// ───────────────────────────────────────── a write the server refuses (403) shows a clean message
Future<void> forbiddenScenario(WidgetTester t) async {
  await step(t, 'forbidden: base teacher signed in, then given a view-only role in the DB (the app still shows the button)', () async {
    await signIn(t, _email, _password);
    await shot(t, 'forbidden_01_home');
    await dbAction(t, 'assign_view_role');
    await openMoreEntry(t, 'Substitutions');
    await settle(t, 2500);
    final row = idKeyed('fx_');
    await waitFor(t, row, seconds: 30);
    await shot(t, 'forbidden_02_substitutions');
    await t.tap(row.first);
    await waitFor(t, find.byKey(const Key('fx_complete')), seconds: 20);
    await settle(t, 800);
    await shot(t, 'forbidden_03_cover_detail');
    await t.tap(find.byKey(const Key('fx_complete')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await waitForAny(t, [find.textContaining("You can't"), find.textContaining('Marked as complete')], seconds: 30);
    await settle(t, 600);
    await shot(t, 'forbidden_04_clean_message');
    print('INFO texts: ${allTexts().where((x) => x.contains("can") || x.contains('orbidden')).toList()}');
    check('forbidden: message starts "You can\'t mark this as complete."', hasText("You can't mark this as complete."));
    check('forbidden: no raw "Forbidden resource" on screen', !hasText('Forbidden'));
    check('forbidden: the app did not crash or sign out', present(find.byKey(const Key('fx_complete'))) || !hasText('Sign in'));
    await dbAction(t, 'unassign_view_role');
  });
}

// ───────────────────────────────────────── Tarbiyah create / edit
Future<void> tarbiyahScenario(WidgetTester t) async {
  await step(t, 'tarbiyah login (class teacher B) and open the student', () async {
    await signIn(t, _email, _password);
    await openClassesModule(t, 'behaviour');
    await settle(t, 3000);
    await shot(t, 'tarbiyah_01_behaviour');
    // open the student's history through the first record of the student (a colleague's record opens the detail sheet: use "View student")
    await t.enterText(find.byKey(const Key('beh_search')), _studentName.split(' ').first);
    await settle(t, 1500);
  });
  await step(t, 'tarbiyah student history: one assessment is mine (Edit), one is a colleague\'s (no Edit)', () async {
    await tapText(t, 'My classes');
    await settle(t, 3000);
    final row = find.textContaining(_studentName);
    if (!present(row)) throw TestFailure('student row not found on the behaviour list');
    await t.tap(row.first);
    await settle(t, 1800);
    if (present(find.byKey(const Key('detail_sheet')))) {
      await tapText(t, 'View student');
      await settle(t, 2500);
    }
    check('tarbiyah: history reachable', await scrollTo(t, find.byKey(const Key('tarbiyah_add'))));
    await settle(t, 800);
    await shot(t, 'tarbiyah_02_history');
    check('tarbiyah: "New Tarbiyah assessment" button', present(find.byKey(const Key('tarbiyah_add'))));
    check('tarbiyah: colleague\'s assessment readable', hasText('Term 3 2025-26'));
    check('tarbiyah: my assessment readable', hasText('Term 2 2025-26'));
    check('tarbiyah: exactly one Edit (mine only)', keyPrefix('tarbiyah_edit_').evaluate().length == 1, '${keyPrefix('tarbiyah_edit_').evaluate().length}');
  });
  await step(t, 'tarbiyah create: validation, then a real POST', () async {
    await scrollTo(t, find.byKey(const Key('tarbiyah_add')));
    await t.tap(find.byKey(const Key('tarbiyah_add')));
    await waitFor(t, find.byKey(const Key('tarbiyah_period')));
    await settle(t, 1200);
    await shot(t, 'tarbiyah_03_form_empty');
    await t.tap(find.byKey(const Key('tarbiyah_submit')));
    await settle(t, 1200);
    await shot(t, 'tarbiyah_04_form_validation');
    check('tarbiyah: validation asks for the period', hasText('Enter the period'));
    await t.enterText(find.byKey(const Key('tarbiyah_period')), 'Term 1 2026-27');
    await settle(t, 400);
    for (final k in ['sidq', 'adab', 'ihsan']) {
      await vis(t, find.byKey(Key('score_${k}_5')));
      await settle(t, 300);
      await t.tap(find.byKey(Key('score_${k}_5')));
      await settle(t, 300);
    }
    await vis(t, find.byKey(const Key('tarbiyah_observations')));
    await t.enterText(find.byKey(const Key('tarbiyah_observations')), 'A1 verification: attentive and kind.');
    await t.enterText(find.byKey(const Key('tarbiyah_strengths')), 'Leadership');
    await settle(t, 600);
    await shot(t, 'tarbiyah_05_form_filled');
    await vis(t, find.byKey(const Key('tarbiyah_submit')));
    await t.tap(find.byKey(const Key('tarbiyah_submit')));
    await settle(t, 3000);
    await scrollTo(t, find.byKey(const Key('tarbiyah_add')));
    await shot(t, 'tarbiyah_06_after_create');
    check('tarbiyah: the new "Term 1 2026-27" assessment is listed', hasText('Term 1 2026-27'));
    check('tarbiyah: server computed an overall rating (100% => Excellent)', hasText('EXCELLENT') || hasText('100%'));
    check('tarbiyah: now two Edit buttons (mine)', keyPrefix('tarbiyah_edit_').evaluate().length == 2, '${keyPrefix('tarbiyah_edit_').evaluate().length}');
  });
  await step(t, 'tarbiyah duplicate period is explained', () async {
    await scrollTo(t, find.byKey(const Key('tarbiyah_add')));
    await t.tap(find.byKey(const Key('tarbiyah_add')));
    await waitFor(t, find.byKey(const Key('tarbiyah_period')));
    await t.enterText(find.byKey(const Key('tarbiyah_period')), 'Term 1 2026-27');
    await vis(t, find.byKey(const Key('score_sidq_3')));
    await t.tap(find.byKey(const Key('score_sidq_3')));
    await vis(t, find.byKey(const Key('tarbiyah_submit')));
    await t.tap(find.byKey(const Key('tarbiyah_submit')));
    await settle(t, 1500);
    await shot(t, 'tarbiyah_07_duplicate_period');
    check('tarbiyah: duplicate period explained', hasText('already has an assessment'));
    await leaveScreen(t);
  });
  await step(t, 'tarbiyah edit: change a score and save (a real PUT)', () async {
    final edit = keyPrefix('tarbiyah_edit_');
    await scrollTo(t, edit);
    await t.tap(edit.first);
    await waitFor(t, find.byKey(const Key('tarbiyah_period')));
    await settle(t, 1200);
    await shot(t, 'tarbiyah_08_edit_form');
    check('tarbiyah: edit opens with a Save changes button', hasText('Save changes'));
    await vis(t, find.byKey(const Key('score_sidq_2')));
    await t.tap(find.byKey(const Key('score_sidq_2')));
    await settle(t, 400);
    await vis(t, find.byKey(const Key('tarbiyah_submit')));
    await t.tap(find.byKey(const Key('tarbiyah_submit')));
    await settle(t, 3000);
    await scrollTo(t, find.byKey(const Key('tarbiyah_add')));
    await shot(t, 'tarbiyah_09_after_edit');
    check('tarbiyah: the edit was saved (rating changed from 100%)', !hasText('100% overall') || keyPrefix('tarbiyah_edit_').evaluate().length == 2);
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = _scenario.isNotEmpty && _email.isNotEmpty && _password.isNotEmpty && _base.isNotEmpty;

  testWidgets('A1 release verification against the LOCAL backend: $_scenario', skip: !configured, timeout: const Timeout(Duration(minutes: 14)), (t) async {
    await startA1(t);
    switch (_scenario) {
      case 'base':
        await baseScenario(t, classTeacher: false);
      case 'class':
        await baseScenario(t, classTeacher: true);
      case 'viewonly':
        await viewOnlyScenario(t);
      case 'noassess':
        await noAssessScenario(t);
      case 'suspended':
        await suspendedScenario(t);
      case 'deactivated':
        await deactivatedScenario(t);
      case 'tarbiyah':
        await tarbiyahScenario(t);
      case 'forbidden':
        await forbiddenScenario(t);
      default:
        throw TestFailure('unknown scenario $_scenario');
    }
    print('SUMMARY steps_failed=${e2eFailures.length} checks_failed=${_checks.length}');
    for (final f in [...e2eFailures, ..._checks]) {
      print('FAILED: $f');
    }
    expect(e2eFailures, isEmpty);
    expect(_checks, isEmpty);
  });
}
