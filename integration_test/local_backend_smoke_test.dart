// LOCAL-backend smoke walkthrough (NOT staging, NOT the stub): drives the real app against a backend running on this machine
// (see eldermin-teacher-app-docs/LOCAL_VERIFICATION.md). Credentials and URL come ONLY from --dart-define, nothing is stored here:
//   LOCAL_TEACHER_EMAIL / LOCAL_TEACHER_PASSWORD   subject teacher (teacher A)
//   LOCAL_CLASS_EMAIL / LOCAL_CLASS_PASSWORD       class teacher (teacher B)
//   LOCAL_SCHOOL_SLUG                              school code, typed into the optional "School code" field
//   API_BASE_URL                                   e.g. http://127.0.0.1:3998
//   LOCAL_SCENARIO                                 `full` (default) or `asbuilt` (login + Home only, to document backend bug B0)
// Run with screenshots: tool/dev/capture_local_backend.sh <sim-udid> <out-dir>. When a define is missing the test skips with a message.
// Writes (all on the isolated local DB): one attendance save, one homework grade, one behaviour log - clearly marked below.
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_source_picker.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart'
    show PickedAttachment;
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

const _teacherEmail = String.fromEnvironment('LOCAL_TEACHER_EMAIL');
const _teacherPassword = String.fromEnvironment('LOCAL_TEACHER_PASSWORD');
const _classEmail = String.fromEnvironment('LOCAL_CLASS_EMAIL');
const _classPassword = String.fromEnvironment('LOCAL_CLASS_PASSWORD');
const _slug = String.fromEnvironment('LOCAL_SCHOOL_SLUG');
const _baseUrl = String.fromEnvironment('API_BASE_URL');
const _scenario =
    String.fromEnvironment('LOCAL_SCENARIO', defaultValue: 'full');

bool get _configured => [
      _teacherEmail,
      _teacherPassword,
      _classEmail,
      _classPassword,
      _slug,
      _baseUrl
    ].every((e) => e.isNotEmpty);

final _failures = <String>[];
var _shotNo = 0;

/// Wall-clock budget of the running step: every wait/retry helper calls [_guard], so no step can spin forever.
final _stepWatch = Stopwatch()..start();
const _stepBudget = Duration(seconds: 240);

void _guard(String where) {
  if (_stepWatch.elapsed > _stepBudget)
    throw TestFailure(
        'step time budget (${_stepBudget.inSeconds}s) exceeded in $where');
}

Future<void> settle(WidgetTester t, [int ms = 1200]) {
  _guard('settle');
  return t.pump(Duration(milliseconds: ms));
}

/// Prints the SHOT marker that tool/dev/capture_local_backend.sh turns into a simulator screenshot.
Future<void> shot(WidgetTester t, String name, {int ms = 1500}) async {
  await t.pump(Duration(milliseconds: ms));
  _shotNo++;
  print('SHOT:lv_${_shotNo.toString().padLeft(2, '0')}_$name');
  await t
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    _guard('waitFor $f');
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder navLabel(String label) => find.descendant(
    of: find.byType(BottomNavigationBar), matching: find.text(label));
Finder tf(String label) => find.widgetWithText(TextFormField, label);

const _errorKeys = [
  'screen_error',
  'section_error',
  'screen_forbidden',
  'section_forbidden',
  'screen_unavailable',
  'section_unavailable'
];
const _emptyKeys = ['screen_empty', 'section_empty'];

/// Fails the step when an error/forbidden/unavailable state is on screen (empty states only when [allowEmpty] is false).
void expectNoBadStates(String where, {bool allowEmpty = true}) {
  final keys = [..._errorKeys, if (!allowEmpty) ..._emptyKeys];
  for (final k in keys) {
    if (find.byKey(Key(k)).evaluate().isNotEmpty)
      throw TestFailure('$where shows $k');
  }
  final empties = _emptyKeys
      .where((k) => find.byKey(Key(k)).evaluate().isNotEmpty)
      .toList();
  if (empties.isNotEmpty)
    print('NOTE $where: empty state(s) on screen: $empties');
}

/// Runs one named step; a failure or uncaught exception is recorded (the test fails at the end) and the app is returned to the shell.
Future<void> step(
    WidgetTester t, String name, Future<void> Function() body) async {
  // LOCAL_SCENARIO=behaviour: only the behaviour step runs (re-checks the single behaviour write without repeating the other writes).
  if (_scenario == 'behaviour' &&
      !name.contains('behaviour home/log') &&
      !name.contains('login') &&
      !name.contains('B1')) return;
  print('STEP $name');
  _stepWatch
    ..reset()
    ..start();
  try {
    await body();
    final ex = t.takeException();
    if (ex != null) throw TestFailure('uncaught exception: $ex');
    print('STEP_OK $name');
  } catch (e) {
    final msg = '$e'.split('\n').first;
    print('STEP_FAIL $name: $msg');
    _failures.add('$name: $msg');
    try {
      await shot(t, 'FAILED_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}',
          ms: 300);
    } catch (_) {}
    t.takeException();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await recoverToShell(t);
  }
}

Future<void> recoverToShell(WidgetTester t) async {
  try {
    _stepWatch
      ..reset()
      ..start();
    await leaveToShell(t);
  } catch (e) {
    print('NOTE recoverToShell: $e');
  }
}

/// Taps the CONFIRM ("Discard") button of any unsaved-changes dialog. NEVER taps Cancel / Keep editing (tapping Cancel is what made the first
/// version of this test loop for 18 minutes on the Log-behaviour form). Returns true when a dialog was handled. Bounded: one tap, no loop.
Future<bool> confirmDiscardIfShown(WidgetTester t) async {
  for (final f in [
    find.byKey(const Key('discard_confirm')),
    find.byKey(const Key('confirm_dialog_confirm')),
    find.widgetWithText(TextButton, 'Discard'),
    find.widgetWithText(FilledButton, 'Discard'),
  ]) {
    if (f.evaluate().isNotEmpty) {
      await t.tap(
          f.first); // unsaved edits are dropped on purpose (nothing is sent)
      await settle(t, 900);
      return true;
    }
  }
  return false;
}

/// Leaves ONE screen: taps back and, if the app shows its unsaved-changes dialog, taps "Discard". Never taps Cancel.
Future<void> leaveScreen(WidgetTester t) async {
  await t.pageBack();
  await settle(t, 900);
  await confirmDiscardIfShown(t);
}

Future<void> back(WidgetTester t) => leaveScreen(t);

/// Pops screens until the bottom-nav shell is visible: at most 6 attempts, then fails with a clear message (never loops unbounded).
Future<void> leaveToShell(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty &&
        find.byType(Dialog).evaluate().isEmpty) return;
    if (!await confirmDiscardIfShown(t)) await back(t);
  }
  if (find.byType(BottomNavigationBar).evaluate().isEmpty)
    throw TestFailure('could not get back to the home shell after 6 attempts');
}

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(find.byType(Scrollable).last, Offset(0, -dy));
  await settle(t, 600);
}

Future<void> openIntroSkipToLogin(WidgetTester t) async {
  app.main();
  await t.pump(const Duration(milliseconds: 300));
  await waitFor(t, find.text('Skip'));
  await t.tap(find.text('Skip'));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

/// Types the credentials and taps Sign in. Returns once Home shows, or throws with the on-screen error text.
Future<void> signIn(WidgetTester t, String email, String password,
    {String? schoolCode}) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), password);
  if (schoolCode != null) {
    if (find.widgetWithText(TextFormField, 'School code').evaluate().isEmpty) {
      await t.tap(find.byKey(const Key('school_code_toggle')));
      await settle(t, 500);
    }
    await t.enterText(tf('School code'), schoolCode);
  }
  await t.tap(find.text('Sign in'));
  for (var i = 0; i < 100; i++) {
    _guard('signIn');
    await t.pump(const Duration(milliseconds: 250));
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
      await settle(t, 2500);
      return;
    }
    final err = _visibleLoginError(t);
    if (err != null) throw TestFailure('login error shown: $err');
  }
  throw TestFailure('login did not reach Home');
}

String? _visibleLoginError(WidgetTester t) {
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? '';
    if (s.contains('nvalid') ||
        s.contains('Something went wrong') ||
        s.contains('credentials') ||
        s.contains('not found')) return s;
  }
  return null;
}

Future<void> signOutViaUi(WidgetTester t) async {
  await t.tap(navLabel('More'));
  await settle(t, 900);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200,
      scrollable: find.byType(Scrollable).last);
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.text('Sign out of Eldermin Teacher?'));
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

class TestSourcePicker implements LessonPlanSourcePicker {
  PickedAttachment? next;
  @override
  Future<PickedAttachment?> pick() async => next;
}

Finder keyPrefix(String p) => find.byWidgetPredicate((w) =>
    w.key is ValueKey<String> &&
    (w.key as ValueKey<String>).value.startsWith(p));

/// Rows keyed `<prefix><24-hex ObjectId>` (so `qa_error` / `qa_progress` are not counted).
Finder idKeyed(String prefix) => find.byWidgetPredicate((w) =>
    w.key is ValueKey<String> &&
    RegExp('^$prefix[0-9a-f]{24}\$')
        .hasMatch((w.key as ValueKey<String>).value));

Iterable<String> allTexts() => [
      for (final w in find.byType(Text).evaluate().map((e) => e.widget as Text))
        w.data ?? w.textSpan?.toPlainText() ?? '',
    ];

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.scrollUntilVisible(f, 250,
      scrollable: find.byType(Scrollable).last, maxScrolls: 40);
  await settle(t, 300);
  await t.tap(f);
  await settle(t, 900);
}

Future<void> openClassesModule(WidgetTester t, String id) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1000);
  final tile = find.byKey(ValueKey('module_$id'));
  await t.scrollUntilVisible(tile, 250,
      scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  // at most 3 attempts: a tap on a tile that sits at the edge of the safe area can be swallowed once
  for (var i = 0; i < 3; i++) {
    await t.ensureVisible(tile);
    await settle(t, 400);
    await t.tap(tile, warnIfMissed: false);
    await settle(t, 1500);
    if (tile.evaluate().isEmpty) return; // left the Classes grid
  }
  throw TestFailure('could not open Classes module $id after 3 taps');
}

Future<void> openMoreEntry(WidgetTester t, String title) async {
  await t.tap(navLabel('More'));
  await settle(t, 900);
  await tapText(t, title);
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 5000));
  await settle(t, 500);
}

class TestWho {
  final String label;
  final bool isClass;
  final String homework;
  final String lessonPlan;
  final String syllabusSubject;
  const TestWho(this.label, this.isClass, this.homework, this.lessonPlan,
      this.syllabusSubject);
}

Future<void> walk(WidgetTester t, TestWho w, TestSourcePicker picker) async {
  final L = w.label;
  final auth = Get.find<AuthController>();

  await step(t, '$L home', () async {
    await waitFor(t, find.text("Today's classes"));
    expect(auth.staffId, isNotNull,
        reason: 'staffId must come from /staff-portal/me');
    expect(auth.staffId, isNot(auth.teacherProfileId),
        reason: 'staffId != teacherProfileId');
    print(
        'INFO $L staffId from /staff-portal/me: present, distinct from teacherProfileId; isClassTeacher=${auth.isClassTeacher}');
    expect(auth.isClassTeacher, w.isClass);
    expect(
        find.text('Mark Attendance'), w.isClass ? findsWidgets : findsNothing);
    expectNoBadStates('$L home');
    await shot(t, '${L}_home_top');
    await t.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await settle(t, 700);
    await shot(t, '${L}_home_middle');
    await t.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -1200));
    await settle(t, 700);
    for (final s in [
      'Homework to grade',
      'Lesson plans',
      'Parent meetings',
      'Messages'
    ]) {
      expect(find.text(s), findsWidgets, reason: 'Home section "$s"');
    }
    expectNoBadStates('$L home bottom');
    await shot(t, '${L}_home_bottom');
    await t.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, 3000));
    await settle(t, 400);
  });

  await step(t, '$L timetable', () async {
    if (w.isClass) {
      await openMoreEntry(t, 'Timetable');
    } else {
      await t.tap(navLabel('Timetable'));
      await settle(t, 1500);
    }
    await settle(t, 2000);
    expectNoBadStates('$L timetable');
    await shot(t, '${L}_timetable_day');
    await t.tap(find.text('Week'));
    await settle(t, 1200);
    expectNoBadStates('$L timetable week');
    await shot(t, '${L}_timetable_week');
    await scroll(t, 600);
    await shot(t, '${L}_timetable_week_lower');
    if (w.isClass) await back(t);
  });

  if (w.isClass) {
    await step(t,
        '$L attendance mark (DELIBERATE local write: mark all present and save for today)',
        () async {
      await t.tap(navLabel('Attendance'));
      await waitFor(t, find.byKey(const Key('hub_mark_button')));
      await settle(t, 1500);
      expectNoBadStates('$L attendance hub');
      await shot(t, '${L}_attendance_hub_before');
      await t.tap(find.byKey(const Key('hub_mark_button')));
      await waitFor(t, find.byKey(const Key('mark_bottom_bar')));
      await settle(t, 1500);
      expectNoBadStates('$L attendance mark');
      await shot(t, '${L}_attendance_mark_unmarked');
      // a few explicit statuses at the top, rest present
      final chips = find.byWidgetPredicate((x) =>
          x.key is ValueKey<String> &&
          RegExp(r'^chip_[0-9a-f]{24}_absent$')
              .hasMatch((x.key as ValueKey<String>).value));
      if (chips.evaluate().isNotEmpty) {
        await t.tap(chips.first);
        await settle(t, 300);
      }
      if (find
          .byKey(const Key('mark_remaining_present'))
          .evaluate()
          .isNotEmpty) {
        await t.tap(find.byKey(const Key('mark_remaining_present')));
      } else {
        // today was already saved by an earlier run: edit one student (Late) so there is a change to save
        Finder chipOf(String wire) => find.byWidgetPredicate((x) =>
            x.key is ValueKey<String> &&
            RegExp('^chip_[0-9a-f]{24}_$wire\$')
                .hasMatch((x.key as ValueKey<String>).value));
        await t.tap(chipOf('absent').first);
        await settle(t, 500);
        if (find.text('Review & submit').evaluate().isEmpty) {
          await t.tap(chipOf('late')
              .first); // the first student was already Absent from an earlier run
          await settle(t, 500);
        }
      }
      await settle(t, 800);
      await shot(t, '${L}_attendance_mark_ready');
      await t.tap(find.byKey(const Key('submit_button')));
      await waitFor(t, find.byKey(const Key('attendance_confirm_dialog')));
      await settle(t, 800);
      await shot(t, '${L}_attendance_confirm');
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await waitFor(t, find.text('Saved'), seconds: 30);
      await settle(t, 800);
      await shot(t, '${L}_attendance_saved');
      await back(t);
      await waitFor(t, find.byKey(const Key('hub_history_button')));
      await settle(t, 1200);
      await shot(t, '${L}_attendance_hub_after');
    });
    await step(t, '$L attendance history', () async {
      await t.tap(find.byKey(const Key('hub_history_button')));
      await waitFor(t, find.byKey(const Key('history_calendar')));
      await settle(t, 2500);
      expectNoBadStates('$L attendance history');
      await shot(t, '${L}_attendance_history');
      await scroll(t, 500);
      await shot(t, '${L}_attendance_history_day');
      await back(t);
    });
  } else {
    await step(t, '$L attendance is class-teacher only', () async {
      expect(navLabel('Attendance'), findsNothing);
      await t.tap(navLabel('Classes'));
      await settle(t, 1200);
      expect(find.byKey(const ValueKey('module_attendance')), findsNothing);
      await shot(t, '${L}_classes_grid_no_attendance');
    });
  }

  await step(t, '$L students + Student 360 (no fees, no phones)', () async {
    await openClassesModule(t, 'students');
    await waitFor(t, find.byKey(const Key('students_count')));
    await settle(t, 1500);
    expectNoBadStates('$L students');
    await shot(t, '${L}_students_list');
    final rows = keyPrefix('student_');
    final target = w.isClass
        ? find.text('Ahmed Malik')
        : rows.first; // Ahmed Malik carries raw fee fields in the payload
    if (w.isClass) {
      await t.scrollUntilVisible(target, 250,
          scrollable: find.byType(Scrollable).last, maxScrolls: 40);
    }
    await t.tap(target.first);
    await waitFor(t, find.byKey(const Key('student_profile')));
    await settle(t, 2500);
    expectNoBadStates('$L student 360');
    await shot(t, '${L}_student360_top');
    final seen = <String>{};
    for (var i = 0; i < 5; i++) {
      seen.addAll(allTexts());
      await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await settle(t, 400);
      if (i == 1) await shot(t, '${L}_student360_middle');
    }
    await shot(t, '${L}_student360_bottom');
    final blob = seen
        .where((e) => !e.contains('not shown in this app'))
        .join(' | '); // the footnote itself says "Fees ... not shown"
    final feeWord = RegExp(
        r'\bfees?\b|arrear|tuition|invoice|PKR|\bRs\.?\b|12,?000',
        caseSensitive: false);
    final phone = RegExp(r'\+?\d[\d\s\-()]{8,}\d');
    final feeHit = feeWord.firstMatch(blob);
    final phoneHit = phone.firstMatch(blob);
    print(
        'INFO $L Student 360 B5 scan: feeWordHit=${feeHit?.group(0)} phoneHit=${phoneHit == null ? null : "yes"}');
    expect(feeHit, isNull, reason: 'Student 360 must not show fees');
    expect(phoneHit, isNull, reason: 'Student 360 must not show phone numbers');
    await toTop(t);
    await t.scrollUntilVisible(
        find.byKey(const Key('student_behaviour_history')), 250,
        scrollable: find.byType(Scrollable).last, maxScrolls: 30);
    await t.tap(find.byKey(const Key('student_behaviour_history')));
    await settle(t, 3000);
    expectNoBadStates('$L student behaviour history');
    await shot(t, '${L}_student_behaviour_history');
    await back(t);
    await back(t);
    await back(t);
  });

  await step(t, '$L homework list/detail/submissions', () async {
    await openClassesModule(t, 'homework');
    await waitFor(t, find.byKey(const Key('hw_new_fab')));
    await waitFor(t, find.text(w.homework));
    await settle(t, 1200);
    expectNoBadStates('$L homework list', allowEmpty: false);
    await shot(t, '${L}_homework_list');
    await t.tap(find.text(w.homework).first);
    await waitFor(t, find.byKey(const Key('hw_view_submissions')));
    await settle(t, 1200);
    await shot(t, '${L}_homework_detail');
    await t.tap(find.byKey(const Key('hw_view_submissions')));
    await settle(t, 3000);
    expectNoBadStates('$L homework submissions', allowEmpty: false);
    await shot(t, '${L}_homework_submissions');
    if (!w.isClass) {
      // ONE deliberate local grade write (teacher A): grade the first 'to grade' submission
      await t.tap(find.byKey(const Key('chip_toGrade')));
      await settle(t, 800);
      await t.tap(keyPrefix('sub_').first);
      await waitFor(t, find.byKey(const Key('grade_marks')));
      await settle(t, 1200);
      await shot(t, '${L}_homework_grade_sheet');
      await t.enterText(find.byKey(const Key('grade_marks')), '7');
      await t.enterText(
          find.byKey(const Key('grade_feedback')), 'Local verification grade');
      await settle(t, 500);
      await t.tap(find.byKey(const Key('grade_save')));
      await settle(t, 3000);
      await shot(t, '${L}_homework_graded');
    }
    await leaveToShell(t);
  });

  await step(t, '$L behaviour home/log', () async {
    await openClassesModule(t, 'behaviour');
    await waitFor(t, find.byKey(const Key('beh_new_fab')));
    await settle(t, 2500);
    expectNoBadStates('$L behaviour', allowEmpty: false);
    await shot(t, '${L}_behaviour_home');
    // Anti-loop regression: open the form, type something, leave through leaveScreen (back -> app's Discard dialog -> Discard).
    await t.tap(find.byKey(const Key('beh_new_fab')));
    await waitFor(t, find.byKey(const Key('beh_description')));
    // NOTE: the app counts student/category/description (not the title alone) as unsaved changes, so type a description.
    await t.enterText(find.byKey(const Key('beh_description')),
        'Unsaved local verification text');
    await settle(t, 600);
    await t.pageBack();
    await settle(t, 1000);
    await shot(t, '${L}_behaviour_discard_dialog');
    expect(find.text('Discard this entry?'), findsOneWidget,
        reason: 'the app must ask before dropping typed text');
    expect(await confirmDiscardIfShown(t), isTrue);
    await waitFor(t, find.byKey(const Key('beh_new_fab')));
    expect(find.byKey(const Key('beh_title')), findsNothing,
        reason: 'form must be closed after Discard');
    if (w.isClass &&
        find.text('Local verification note').evaluate().isNotEmpty) {
      print(
          'NOTE $L behaviour: the local verification entry already exists from an earlier run, not writing a second one');
    } else if (w.isClass) {
      // ONE deliberate local write (class teacher B): log a behaviour record
      await t.tap(find.byKey(const Key('beh_new_fab')));
      await waitFor(t, find.byKey(const Key('beh_student_picker')));
      await settle(t, 1000);
      await t.tap(find.byKey(const Key('beh_student_picker')));
      await waitFor(t, find.byKey(const Key('beh_picker_search')));
      await settle(t, 1500);
      await t.enterText(find.byKey(const Key('beh_picker_search')), 'Momina');
      await settle(t, 800);
      await t.tap(find.text('Momina Iqbal').last);
      await settle(t, 1000);
      await t.enterText(
          find.byKey(const Key('beh_title')), 'Local verification note');
      await t.enterText(find.byKey(const Key('beh_description')),
          'Helped a classmate (local verification, dummy data).');
      await t.tap(find.text(
          'Helping Others')); // a category is required, otherwise the form refuses to save
      await settle(t, 600);
      await shot(t, '${L}_behaviour_new_filled');
      await t.scrollUntilVisible(find.byKey(const Key('beh_submit')), 250,
          scrollable: find.byType(Scrollable).last);
      await t.tap(find.byKey(const Key('beh_submit')));
      await settle(t, 3500);
      expect(find.byKey(const Key('beh_submit_error')), findsNothing,
          reason: 'behaviour save failed');
      // success = the form closed and the list (with its Log behaviour button) is back, with the new entry on top
      await waitFor(t, find.byKey(const Key('beh_new_fab')));
      await waitFor(t, find.text('Local verification note'));
      await settle(t, 800);
      await shot(t, '${L}_behaviour_after_log');
    }
    await leaveToShell(t);
  });

  await step(t, '$L lesson plans list/detail/new/upload-parse', () async {
    await openClassesModule(t, 'lesson_plans');
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await waitFor(t, find.text(w.lessonPlan));
    await settle(t, 1200);
    expectNoBadStates('$L lesson plans', allowEmpty: false);
    await shot(t, '${L}_lessonplans_list');
    await t.tap(find.text(w.lessonPlan).first);
    await settle(t, 2000);
    await shot(t, '${L}_lessonplan_detail');
    await back(t);
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await t.tap(find.byKey(const Key('lp_new_fab')));
    await waitFor(t, find.byKey(const Key('lp_save_draft')));
    await settle(t, 1000);
    await shot(t, '${L}_lessonplan_new_form');
    await back(t);
    await waitFor(t, find.byKey(const Key('lp_new_fab')));
    await t.tap(find.byKey(const Key('lp_upload_action')));
    await waitFor(t, find.byKey(const Key('lp_pick_file')));
    picker.next = _tempFile('Local verification plan.docx', 2048);
    await t.tap(find.byKey(const Key('lp_pick_file')));
    await waitFor(t, find.byKey(const Key('lp_picked')));
    await t.tap(find.byKey(const Key('lp_parse')));
    await waitFor(t, find.byKey(const Key('lp_parse_failure')), seconds: 60);
    await settle(t, 800);
    print(
        'INFO $L parse-upload failure state shown (expected locally: no AI key / dummy docx)');
    await shot(t, '${L}_lessonplan_parse_failure');
    await leaveToShell(t);
  });

  await step(t, '$L syllabus list/detail/weekly planner', () async {
    await openClassesModule(t, 'syllabus');
    await waitFor(t, find.byKey(const Key('syl_planner_card')));
    await settle(t, 1800);
    expectNoBadStates('$L syllabus', allowEmpty: false);
    await shot(t, '${L}_syllabus_list');
    await t.tap(find.text(w.syllabusSubject).first);
    await waitFor(t, find.byKey(const Key('syl_overall_bar')));
    await settle(t, 1200);
    expectNoBadStates('$L syllabus detail');
    await shot(t, '${L}_syllabus_detail');
    await back(t);
    await waitFor(t, find.byKey(const Key('syl_planner_card')));
    await t.tap(find.byKey(const Key('syl_planner_card')));
    await waitFor(t, find.byKey(const Key('planner_label')));
    await settle(t, 2000);
    expectNoBadStates('$L planner');
    await shot(t, '${L}_syllabus_weekly_planner');
    await leaveToShell(t);
  });

  await step(t, '$L assessments list/detail/marks', () async {
    await openClassesModule(t, 'assessments');
    await waitFor(t, find.byKey(const Key('asm_quiz_card')));
    await settle(t, 2500);
    expectNoBadStates('$L assessments', allowEmpty: false);
    await t.tap(find.byKey(const Key('chip_all')));
    await settle(t, 800);
    await shot(t, '${L}_assessments_list');
    for (final name in ['Unit Test 1 - Mathematics', 'Mid Term 2026']) {
      await toTop(t);
      await t.tap(find.byKey(const Key('chip_all')));
      await settle(t, 500);
      try {
        await t.scrollUntilVisible(find.text(name), 250,
            scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      } catch (_) {
        print('NOTE $L assessments: "$name" not listed for this teacher');
        continue;
      }
      await tapText(t, name);
      await settle(t, 1500);
      expectNoBadStates('$L assessment detail $name');
      await shot(t,
          '${L}_assessment_detail_${name.startsWith('Unit') ? 'unit_test' : 'mid_term'}');
      final marksBtn = keyPrefix('asm_marks_');
      if (marksBtn.evaluate().isEmpty) {
        print(
            'NOTE $L "$name": no marks entry button (no subject of this teacher)');
      } else {
        await t.tap(marksBtn.first);
        await waitFor(
            t,
            find.byWidgetPredicate((w) =>
                w.key == const Key('marks_save_button') ||
                w.key == const Key('marks_locked_note')));
        await settle(t, 2500);
        expectNoBadStates('$L marks grid $name');
        final locked =
            find.byKey(const Key('marks_locked_note')).evaluate().isNotEmpty;
        print(
            'INFO $L marks grid "$name": verified-rows locked note=$locked, lock icons=${keyPrefix('marks_lock_').evaluate().length}');
        await shot(t,
            '${L}_marks_grid_${name.startsWith('Unit') ? 'unit_test' : 'mid_term'}');
        final fields = keyPrefix('marks_field_');
        if (name.startsWith('Unit') && fields.evaluate().isNotEmpty) {
          await t.enterText(fields.first,
              '75'); // total is 50 -> client must refuse, nothing is sent
          await settle(t, 500);
          await t.tap(find.byKey(const Key('marks_save_button')));
          await settle(t, 1200);
          final refused = find
                  .byKey(const Key('marks_invalid_banner'))
                  .evaluate()
                  .isNotEmpty ||
              keyPrefix('marks_error_').evaluate().isNotEmpty;
          print('INFO $L >total mark refused client-side: $refused');
          await shot(t, '${L}_marks_over_total_refused');
          expect(refused, isTrue,
              reason: 'mark above the total must be refused by the client');
          expect(find.byKey(const Key('marks_confirm_save')), findsNothing);
        }
        if (name.startsWith('Mid'))
          expect(
              locked ||
                  keyPrefix('marks_lock_').evaluate().isNotEmpty ||
                  w.isClass,
              isTrue,
              reason: 'verified rows must be locked');
        await back(t);
        await settle(t, 600);
      }
      await back(t);
      await settle(t, 800);
      await toTop(t);
    }
    if (w.isClass) {
      await waitFor(t, find.byKey(const Key('asm_remarks_card')));
      await toTop(t);
      await t.tap(find.byKey(const Key('asm_remarks_card')));
      await waitFor(t, find.byType(TextField));
      await settle(t, 2000);
      expectNoBadStates('$L report remarks');
      await shot(t, '${L}_report_remarks');
      await back(t);
    } else {
      expect(find.byKey(const Key('asm_remarks_card')), findsNothing,
          reason: 'report remarks are class-teacher only');
    }
    await toTop(t);
    await t.tap(find.byKey(const Key('asm_quiz_card')));
    await settle(t, 3000);
    expectNoBadStates('$L quiz attempts', allowEmpty: true);
    final n = idKeyed('qa_').evaluate().length;
    // The server returns 3 (A) / 2 (B) class-scoped attempts, all Mathematics. The app additionally filters by SUBJECT: B (class teacher, teaches
    // English) must see none of them, A (teaches Mathematics in 5-A and 6-A) sees all 3.
    print(
        'INFO $L quiz attempts listed: $n (expected ${w.isClass ? 0 : 3}: class AND subject scoping in the app)');
    await shot(t, '${L}_quiz_attempts');
    expect(n, w.isClass ? 0 : 3,
        reason: 'quiz attempts must be scoped to the teacher\'s classes');
    await leaveToShell(t);
  });

  await step(t, '$L curriculum', () async {
    await openMoreEntry(t, 'Curriculum');
    await settle(t, 2500);
    expectNoBadStates('$L curriculum', allowEmpty: false);
    await shot(t, '${L}_curriculum_list');
    await t.tap(keyPrefix('cur_').first);
    await settle(t, 2000);
    await shot(t, '${L}_curriculum_detail');
    await back(t);
    await back(t);
  });

  await step(t, '$L library', () async {
    await openMoreEntry(t, 'Library');
    await waitFor(t, find.byKey(const Key('lib_search')));
    await settle(t, 2500);
    expectNoBadStates('$L library', allowEmpty: false);
    expect(keyPrefix('book_').evaluate().length, greaterThan(0));
    await shot(t, '${L}_library');
    await back(t);
  });

  await step(t, '$L notifications', () async {
    await toTop(t);
    await t.tap(find.byKey(const Key('bell_badge')));
    await settle(t, 3000);
    expectNoBadStates('$L notifications');
    await shot(t, '${L}_notifications');
    await back(t);
  });

  await step(t, '$L more', () async {
    await t.tap(navLabel('More'));
    await settle(t, 1200);
    await shot(t, '${L}_more');
  });
}

File _tempFileOf(String name, int bytes) =>
    File('${Directory.systemTemp.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 37));
PickedAttachment _tempFile(String name, int bytes) {
  final f = _tempFileOf(name, bytes);
  return PickedAttachment(name: name, path: f.path, size: bytes);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!_configured) {
    print(
        'SKIPPED local_backend_smoke_test: pass --dart-define for API_BASE_URL, LOCAL_TEACHER_EMAIL, LOCAL_TEACHER_PASSWORD, '
        'LOCAL_CLASS_EMAIL, LOCAL_CLASS_PASSWORD, LOCAL_SCHOOL_SLUG (see the header of this file).');
  }

  testWidgets(
      'LOCAL backend smoke walkthrough (class teacher B, then teacher A)',
      skip: !_configured,
      timeout: const Timeout(Duration(minutes: 14)), (t) async {
    final picker = TestSourcePicker();
    Get.put<LessonPlanSourcePicker>(picker, permanent: true);
    await openIntroSkipToLogin(t);

    if (_scenario == 'asbuilt') {
      await step(
          t,
          'asbuilt login',
          () async =>
              signIn(t, _teacherEmail, _teacherPassword, schoolCode: _slug));
      await shot(t, 'asbuilt_home');
      print('WALKTHROUGH_DONE failures=${_failures.length}');
      return;
    }

    // B1 check from the app side: sign in WITH the school code typed (slug sent to POST /auth/login).
    await step(t, 'B1 login with school code (class teacher B)', () async {
      try {
        await signIn(t, _classEmail, _classPassword, schoolCode: _slug);
        print(
            'INFO B1: login WITH school code succeeded for a user stored with schoolSlug');
      } catch (e) {
        print(
            'INFO B1: login WITH school code FAILED, message shown to user: $e');
        await shot(t, 'B1_login_with_school_code_error');
        rethrow;
      }
    });
    if (find.byType(BottomNavigationBar).evaluate().isEmpty) {
      await step(t, 'login B without school code (fallback)',
          () async => signIn(t, _classEmail, _classPassword));
    }
    await walk(
        t,
        const TestWho(
            'B', true, 'Essay: My school', 'Descriptive writing', 'English'),
        picker);
    if (_scenario == 'behaviour') {
      print('WALKTHROUGH_DONE failures=${_failures.length}');
      expect(_failures, isEmpty);
      return;
    }
    await step(t, 'B sign out via More', () async {
      await signOutViaUi(t);
      await shot(t, 'signed_out_login_screen');
    });
    await step(t, 'login A (no school code)',
        () async => signIn(t, _teacherEmail, _teacherPassword));
    await walk(
        t,
        const TestWho('A', false, 'Fractions worksheet',
            'Subtracting fractions', 'Mathematics'),
        picker);
    await step(t, 'A sign out via More', () async => signOutViaUi(t));

    print('WALKTHROUGH_DONE failures=${_failures.length}');
    for (final f in _failures) {
      print('FAILED_STEP $f');
    }
    expect(_failures, isEmpty);
  });
}
