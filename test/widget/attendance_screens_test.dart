import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_history_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_history_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_mark_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attendance_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/layout_probe.dart';

void main() {
  late FakeStudentsRepository students;
  late FakeAttendanceRepository attendance;
  late AttendanceController c;
  final now = DateTime(2026, 10, 5, 9);
  final roster = [for (var i = 1; i <= 5; i++) student(i)];

  // real Plus Jakarta Sans glyph widths (flutter_test's default Ahem font is far wider and fakes overflows)
  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    students = FakeStudentsRepository()..roster = (_) async => roster;
    attendance = FakeAttendanceRepository();
  });
  tearDown(Get.reset);

  Future<void> boot(WidgetTester t, Widget screen, {bool classTeacher = true, List<Map<String, Object?>>? assignments, String token = 'tok', bool tall = true, double width = 430, double scale = 1.0, TextDirection dir = TextDirection.ltr}) async {
    final h = (await t.runAsync(() => signedIn(classTeacher: classTeacher, classTeacherAssignments: assignments, token: token)))!;
    c = AttendanceController(students: students, attendance: attendance, auth: h.auth, permissions: h.perms, clock: () => now);
    Get.put(c);
    Get.put(AttendanceHistoryController(attendance: attendance, daily: c, clock: () => now));
    if (tall) {
      await t.binding.setSurfaceSize(Size(width, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
    }
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: probeWrap(screen, scale: scale, dir: dir)));
    await t.pump();
    await t.pump();
  }

  Finder chip(int i, AttendanceStatus s) => find.byKey(ValueKey('chip_${roster[i].id}_${s.wire}'));

  group('mark screen', () {
    testWidgets('shows the roster with five toggles per student and "N not marked"', (t) async {
      await boot(t, const AttendanceMarkScreen());
      expect(find.text('First1 Last1'), findsOneWidget);
      expect(find.text('Present'), findsNWidgets(5));
      expect(find.text('Half'), findsNWidgets(5));
      expect(find.text('Leave'), findsNWidgets(5));
      expect(find.text('0 of 5 marked · 5 not marked'), findsOneWidget);
      expect(find.text('Mark all present'), findsOneWidget);
      expect(find.text('Today · Monday, 5 October'), findsOneWidget);
    });

    testWidgets('tapping toggles marks; Mark remaining present fills only the unmarked', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(chip(1, AttendanceStatus.absent));
      await t.pump();
      expect(c.marks[roster[1].id], AttendanceStatus.absent);
      expect(find.text('1 of 5 marked · 4 not marked'), findsOneWidget);
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      expect(c.marks[roster[1].id], AttendanceStatus.absent);
      expect(c.marks[roster[0].id], AttendanceStatus.present);
      expect(find.text('All 5 marked'), findsOneWidget);
    });

    testWidgets('submitting with students unmarked shows the "N not marked" prompt and sends nothing', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(chip(0, AttendanceStatus.present));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      expect(find.byKey(const Key('not_marked_snack')), findsOneWidget);
      expect(find.textContaining('4 students aren'), findsOneWidget);
      expect(find.byKey(const Key('attendance_confirm_dialog')), findsNothing);
      expect(attendance.submitted, isEmpty);
      expect(find.byKey(const Key('row_not_marked')), findsNWidgets(4));
    });

    testWidgets('complete -> confirmation summary with counts -> submit saves and shows Saved', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(chip(2, AttendanceStatus.absent));
      await t.tap(chip(3, AttendanceStatus.late));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      expect(find.byKey(const Key('attendance_confirm_dialog')), findsOneWidget);
      expect(find.text('5 students'), findsOneWidget);
      expect(find.text('Present 3'), findsOneWidget);
      expect(find.text('Absent 1'), findsOneWidget);
      expect(find.text('Late 1'), findsOneWidget);
      expect(find.text('Absent: First3 Last3'), findsOneWidget);
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(attendance.submitted.single, hasLength(5));
      expect(find.byKey(const Key('saved_snack')), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byKey(const Key('saved_banner')), findsOneWidget);
    });

    testWidgets('failed save: error banner + Retry, every mark preserved; retry saves', (t) async {
      attendance.onSubmit = (_, __) async => throw ApiException("Couldn't reach Eldermin. Check your internet connection.");
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.tap(chip(1, AttendanceStatus.excused));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('submit_error_banner')), findsOneWidget);
      expect(find.textContaining('marks are kept'), findsOneWidget);
      expect(find.byKey(const Key('submit_retry')), findsOneWidget);
      expect(c.marks[roster[1].id], AttendanceStatus.excused);
      expect(c.marks, hasLength(5));
      attendance.onSubmit = (_, __) async {};
      await t.tap(find.byKey(const Key('submit_retry')));
      await t.pump();
      await t.pump();
      expect(attendance.submitted, hasLength(2));
      expect(find.byKey(const Key('submit_error_banner')), findsNothing);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('403 from the server is shown as an access message; marks survive', (t) async {
      attendance.onSubmit = (_, __) async => throw ApiException('Forbidden resource', statusCode: 403);
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(find.textContaining("You can't mark attendance for this class"), findsOneWidget);
      expect(c.marks, hasLength(5));
    });

    testWidgets('existing records are pre-filled and editing enables submit only after a change', (t) async {
      attendance.range = (_, __, ___, ____) async => [for (final s in roster) record(s, DateTime.utc(2026, 10, 5), 'present')];
      await boot(t, const AttendanceMarkScreen());
      expect(find.text('All 5 marked'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget); // nothing changed yet
      await t.tap(chip(0, AttendanceStatus.late));
      await t.pump();
      expect(find.text('Review & submit'), findsOneWidget);
    });

    testWidgets('loading shimmer, 403, error with retry, empty class', (t) async {
      final gate = Completer<List<dynamic>>();
      students.roster = (_) async {
        await gate.future;
        return roster;
      };
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await t.pump();
      await t.pump();
      expect(find.text('First1 Last1'), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      students = FakeStudentsRepository()..roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      var fail = true;
      students = FakeStudentsRepository()..roster = (_) async => fail ? throw ApiException('boom', statusCode: 500) : roster;
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pump();
      await t.pump();
      expect(find.text('First1 Last1'), findsOneWidget);

      Get.reset();
      Get.testMode = true;
      students = FakeStudentsRepository()..roster = (_) async => [];
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
    });

    testWidgets('a read-only (older) day disables toggles and explains why', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await c.openDay(DateTime(2026, 9, 1));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('read_only_banner')), findsOneWidget);
      await t.tap(chip(0, AttendanceStatus.present));
      await t.pump();
      expect(c.marks, isEmpty);
      expect(tester(t).widget<EmPrimaryButton>(find.byKey(const Key('submit_button'))).onPressed, isNull); // D6: EmPrimaryButton replaces the raw ElevatedButton
    });

    testWidgets('search narrows the list by name or roll number', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.enterText(find.byKey(const Key('mark_search')), 'First3');
      await t.pump();
      expect(find.text('First3 Last3'), findsOneWidget);
      expect(find.text('First1 Last1'), findsNothing);
      await t.enterText(find.byKey(const Key('mark_search')), 'zzz');
      await t.pump();
      expect(find.byKey(const Key('mark_search_empty')), findsOneWidget);
    });

    testWidgets('not a class teacher: honest "not available" page, nothing requested', (t) async {
      await boot(t, const AttendanceMarkScreen(), classTeacher: false);
      expect(find.byKey(const Key('attendance_not_class_teacher')), findsOneWidget);
      expect(attendance.rangeCalls, isEmpty);
      expect(students.calls, isEmpty);
    });
  });

  group('mark screen: subject-wise school (hotfix D13)', () {
    testWidgets('a DAILY school shows no subject picker and saves without a subject', (t) async {
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('subject_bar')), findsNothing);
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(attendance.submitted.single.every((w) => w.subject == null), isTrue);
    });

    testWidgets('a SUBJECT-WISE school shows the subject chips (first selected); choosing one reads it; the save carries it', (t) async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      await boot(t, const AttendanceMarkScreen());
      await t.pump();
      expect(find.byKey(const Key('subject_bar')), findsOneWidget);
      expect(tester(t).widget<EmChip>(find.byKey(const ValueKey('subject_chip_English'))).selected, isTrue);
      expect(tester(t).widget<EmChip>(find.byKey(const ValueKey('subject_chip_Maths'))).selected, isFalse);
      await t.tap(find.byKey(const ValueKey('subject_chip_Maths')));
      await t.pump();
      await t.pump();
      expect(c.selectedSubject.value, 'Maths');
      expect(attendance.rangeCalls.last.subject, 'Maths');
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      expect(find.textContaining('Maths'), findsWidgets); // the confirmation names the subject
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(attendance.submitted.single.every((w) => w.subject == 'Maths'), isTrue);
    });

    testWidgets('changing subject with unsaved marks asks first; Keep editing leaves everything as it was', (t) async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => ['English', 'Maths'];
      await boot(t, const AttendanceMarkScreen());
      await t.pump();
      await t.tap(chip(0, AttendanceStatus.absent));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('subject_chip_Maths')));
      await t.pump();
      expect(find.byKey(const Key('discard_dialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('discard_keep')));
      await t.pump();
      expect(c.selectedSubject.value, 'English');
      expect(c.marks[roster[0].id], AttendanceStatus.absent);
    });

    testWidgets('subject-wise with no subjects set up: explanatory banner, nothing can be saved', (t) async {
      attendance.mode = () async => AttendanceMode.subjectWise;
      attendance.subjectNames = () async => [];
      await boot(t, const AttendanceMarkScreen());
      await t.pump();
      expect(find.byKey(const Key('no_subjects_banner')), findsOneWidget);
      expect(find.byKey(const Key('subject_bar')), findsNothing);
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      expect(c.canSubmit, isFalse);
      expect(attendance.submitted, isEmpty);
    });
  });

  group('hub', () {
    testWidgets('class teacher: today status, mark + history buttons', (t) async {
      attendance.range = (_, __, ___, ____) async => [record(roster[0], DateTime.utc(2026, 10, 5), 'present'), record(roster[1], DateTime.utc(2026, 10, 5), 'absent')];
      await boot(t, const AttendanceScreen());
      await c.load();
      await t.pump();
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Partly marked today'), findsOneWidget);
      expect(find.text("Edit today's attendance"), findsOneWidget);
      expect(find.byKey(const Key('hub_history_button')), findsOneWidget);
    });

    testWidgets('nothing marked: "isn\'t marked yet" and the mark CTA', (t) async {
      await boot(t, const AttendanceScreen());
      await c.load();
      await t.pump();
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.text("Mark today's attendance"), findsOneWidget);
    });

    testWidgets('a non-class-teacher sees the not-available page', (t) async {
      await boot(t, const AttendanceScreen(embedded: true), classTeacher: false);
      expect(find.byKey(const Key('attendance_not_class_teacher')), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets('calendar with day markers, day detail with names and the Edit button for an editable day', (t) async {
      attendance.range = (_, __, first, last) async => first == last
          ? []
          : [
              for (final s in roster) record(s, DateTime.utc(2026, 10, 5), s == roster[2] ? 'absent' : 'present'),
              for (final s in roster) record(s, DateTime.utc(2026, 10, 2), 'present'),
              record(roster[0], DateTime.utc(2026, 10, 1), 'late'),
            ];
      await boot(t, const AttendanceHistoryScreen());
      expect(find.byKey(const Key('history_calendar')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker_2026-10-05')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker_2026-10-02')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker_2026-10-01')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker_2026-10-03')), findsNothing);
      expect(find.text('Marked 5 of 5'), findsOneWidget);
      expect(find.text('Absent 1'), findsOneWidget);
      expect(find.text('First3 Last3'), findsOneWidget); // listed under Absent
      expect(find.byKey(const Key('history_edit_button')), findsOneWidget);
      expect(find.text('Edit this day'), findsOneWidget);
    });

    testWidgets('a day without records says so; an old day is view-only', (t) async {
      await boot(t, const AttendanceHistoryScreen());
      expect(find.byKey(const Key('history_day_empty')), findsOneWidget);
      expect(find.text('Mark this day'), findsOneWidget);
      Get.find<AttendanceHistoryController>().selectDay(DateTime(2026, 10, 1));
      Get.find<AttendanceHistoryController>().focusMonth(DateTime(2026, 9, 1));
      Get.find<AttendanceHistoryController>().selectDay(DateTime(2026, 9, 10));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('history_read_only')), findsOneWidget);
      expect(find.byKey(const Key('history_edit_button')), findsNothing);
    });

    testWidgets('error shows retry; 403 shows no-access; both keep the calendar usable', (t) async {
      attendance.range = (_, __, first, last) async => first == last ? [] : throw ApiException('boom', statusCode: 500);
      await boot(t, const AttendanceHistoryScreen());
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      expect(find.byKey(const Key('history_calendar')), findsOneWidget);
      attendance.range = (_, __, first, last) async => first == last ? [] : throw ApiException('Forbidden', statusCode: 403);
      await t.tap(find.text('Try again'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
    });
  });

  // D6 layout probes: widths 320/360/375/430 x text scale 1.0/1.3 x LTR/RTL
  group('D6 layout probes', () {
    for (final w in probeWidths) {
      for (final sc in probeScales) {
        for (final d in probeDirs) {
          testWidgets(probeName('mark screen', w, sc, d), (t) async {
            await boot(t, const AttendanceMarkScreen(), width: w, scale: sc, dir: d);
            expectNoLayoutError(t);
            // the five status labels never wrap or clip, and every toggle is a 48dp target
            for (final label in ['Present', 'Absent', 'Late', 'Leave', 'Half']) {
              expectOneLine(t, find.text(label), scale: sc);
              expectInsideScreen(t, find.text(label), w);
            }
            for (final s in AttendanceStatus.values) {
              expect(t.getSize(chip(0, s)).height, greaterThanOrEqualTo(48));
            }
            expectInsideScreen(t, find.byKey(const Key('submit_button')), w);
          });
          testWidgets(probeName('hub', w, sc, d), (t) async {
            attendance.range = (_, __, ___, ____) async => [record(roster[0], DateTime.utc(2026, 10, 5), 'present'), record(roster[1], DateTime.utc(2026, 10, 5), 'absent')];
            await boot(t, const AttendanceScreen(), width: w, scale: sc, dir: d);
            expectNoLayoutError(t);
            expectOneLine(t, find.text('2 / 5'), scale: sc);
            expectInsideScreen(t, find.byKey(const Key('hub_mark_button')), w);
            expectInsideScreen(t, find.byKey(const Key('hub_history_button')), w);
            for (final label in ['Present 1', 'Absent 1']) {
              expectOneLine(t, find.text(label), scale: sc);
            }
          });
          testWidgets(probeName('history', w, sc, d), (t) async {
            await boot(t, const AttendanceHistoryScreen(), width: w, scale: sc, dir: d);
            expectNoLayoutError(t);
            expectInsideScreen(t, find.byKey(const Key('history_calendar')), w);
          });
        }
      }
    }
  });

  // D6 follow-up: the "mark remaining" actions of the bottom bar never wrap at text scale 1.0 (320-430); at 1.3x they may.
  group('mark remaining label', () {
    for (final w in probeWidths) {
      testWidgets('"Mark all present" and "Mark remaining present" on one line at ${w.toInt()} x 1.0', (t) async {
        await boot(t, const AttendanceMarkScreen(), width: w);
        expectNoLayoutError(t);
        expectOneLine(t, find.text('Mark all present'), scale: 1.0);
        await t.tap(chip(0, AttendanceStatus.present));
        await t.pump();
        expectOneLine(t, find.text('Mark remaining present'), scale: 1.0);
        expectInsideScreen(t, find.byKey(const Key('mark_remaining_present')), w);
      });
    }
  });

  // D6 follow-up: date selection on the marking screen. Pre-D6 (84d9b42 attendance_mark_screen.dart:80-85,186-187,258,273): day_back / day_forward moved
  // one day inside [today - kAttendanceEditWindowDays, today] and day_pick opened showDatePicker(firstDate: earliestEditable, lastDate: today).
  // The strip shows exactly that window and the calendar entry point (day_pick) is back, with the identical limits.
  group('mark screen: date selection', () {
    // clock = Monday 5 Oct 2026, window = 28 Sep .. 5 Oct (7 days back, never the future)
    String ymd(DateTime d) => ymdOf(d);
    // a day cell of the date picker's grid (the strip behind it also shows day numbers)
    Finder cell(String day) => find.descendant(of: find.byType(GridView), matching: find.text(day));

    testWidgets('the strip lists exactly the allowed window: 28 Sep .. 5 Oct, nothing older, nothing in the future', (t) async {
      await boot(t, const AttendanceMarkScreen());
      final strip = t.widget<EmDateStrip>(find.byType(EmDateStrip));
      expect(strip.days.length, kAttendanceEditWindowDays + 1);
      expect(ymd(strip.days.first), '2026-09-28');
      expect(ymd(strip.days.last), '2026-10-05');
      expect(find.byKey(const Key('day_pick')), findsOneWidget);
    });

    testWidgets('tapping a past day on the strip opens it (the previous / next day are one tap away)', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const ValueKey('mark_day_2026-10-04')));
      await t.pumpAndSettle();
      expect(ymd(c.day.value), '2026-10-04');
      await t.tap(find.byKey(const ValueKey('mark_day_2026-10-05')));
      await t.pumpAndSettle();
      expect(ymd(c.day.value), '2026-10-05');
    });

    testWidgets('calendar entry point: jump to an arbitrary past day of the window (1 Oct) and to its first day (28 Sep, previous month)', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('day_pick')));
      await t.pumpAndSettle();
      expect(find.text('Select date'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      await t.tap(cell('1'));
      await t.pumpAndSettle();
      expect(ymd(c.day.value), '2026-10-01');
      // the earliest allowed day lives in the previous month
      await t.tap(find.byKey(const Key('day_pick')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Previous'));
      await t.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      await t.tap(cell('28'));
      await t.pumpAndSettle();
      expect(ymd(c.day.value), '2026-09-28');
    });

    testWidgets('limits are enforced identically: older than the window (two weeks back) and the future cannot be picked', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('day_pick')));
      await t.pumpAndSettle();
      // future: 6 Oct is disabled and the month cannot move past October
      await t.tap(cell('6'));
      await t.pumpAndSettle();
      expect(find.text('Select date'), findsOneWidget);
      await t.tap(find.byTooltip('Next'));
      await t.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      // past: one month back is September; 27 Sep (outside the 7 days) is disabled and August is out of reach (two weeks, three weeks back)
      await t.tap(find.byTooltip('Previous'));
      await t.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      await t.tap(cell('21'));
      await t.pumpAndSettle();
      await t.tap(cell('27'));
      await t.pumpAndSettle();
      expect(find.text('Select date'), findsOneWidget);
      expect(ymd(c.day.value), '2026-10-05');
      await t.tap(find.byTooltip('Previous'));
      await t.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('unsaved marks: picking another day asks first (Keep editing stays on the day)', (t) async {
      await boot(t, const AttendanceMarkScreen());
      await t.tap(chip(0, AttendanceStatus.absent));
      await t.pump();
      await t.tap(find.byKey(const Key('day_pick')));
      await t.pumpAndSettle();
      await t.tap(cell('1'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('discard_dialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('discard_keep')));
      await t.pump();
      expect(ymd(c.day.value), '2026-10-05');
      expect(c.marks[roster[0].id], AttendanceStatus.absent);
    });
  });
  group('multi-section class teacher', () {
    final two = [
      {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'A', 'name': 'Grade 5 - A'},
      {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'B', 'name': 'Grade 5 - B'},
    ];
    final both = classTeacherJwt([(grade: 'Grade 5', section: 'A'), (grade: 'Grade 5', section: 'B')]);
    final onlyA = classTeacherJwt([(grade: 'Grade 5', section: 'A')]);

    testWidgets('single-class teacher: no class picker, no stale banner (unchanged screen)', (t) async {
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('class_bar')), findsNothing);
      expect(find.byKey(const Key('stale_class_banner')), findsNothing);
      expect(find.byKey(const Key('day_strip')), findsOneWidget);
    });

    testWidgets('two classes: the picker shows both; choosing B reloads for B and the save carries B', (t) async {
      await boot(t, const AttendanceMarkScreen(), assignments: two, token: both);
      expect(find.byKey(const Key('class_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('class_chip_5|a')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('class_chip_5|b')));
      await t.pump();
      await t.pump();
      expect(c.selectedClass.value!.label, 'Grade 5 - B');
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(attendance.submitted.single.map((w) => (w.grade, w.section)).toSet(), {('Grade 5', 'B')});
    });

    testWidgets('switching class with unsaved marks asks first; Keep editing leaves everything as it was', (t) async {
      await boot(t, const AttendanceMarkScreen(), assignments: two, token: both);
      await t.tap(chip(0, AttendanceStatus.absent));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('class_chip_5|b')));
      await t.pump();
      expect(find.byKey(const Key('discard_dialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('discard_keep')));
      await t.pump();
      expect(c.selectedClass.value!.label, 'Grade 5 - A');
      expect(c.marks[roster[0].id], AttendanceStatus.absent);
    });

    testWidgets('a class missing from the token: warning banner with Sign out, submit disabled for it only', (t) async {
      await boot(t, const AttendanceMarkScreen(), assignments: two, token: onlyA);
      expect(find.byKey(const Key('stale_class_banner')), findsNothing); // class A is fine
      await t.tap(find.byKey(const ValueKey('class_chip_5|b')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stale_class_banner')), findsOneWidget);
      expect(find.text('Your sign-in predates your new class. Sign out and back in to mark Grade 5 - B.'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      expect(c.canSubmit, isFalse);
      expect(t.widget<EmPrimaryButton>(find.byKey(const Key('submit_button'))).onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('class_chip_5|a')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('discard_dialog')), findsOneWidget); // marks on B are dirty
      await t.tap(find.byKey(const Key('discard_confirm')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stale_class_banner')), findsNothing);
    });

    testWidgets('the class-scope 403 shows the same prompt (not a generic error) and keeps the marks', (t) async {
      attendance.onSubmit = (_, __) async => throw ApiException('Access denied. You are the class teacher of your own assigned class only.', statusCode: 403);
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stale_class_banner')), findsOneWidget);
      expect(find.byKey(const Key('submit_error_banner')), findsNothing);
      expect(find.byKey(const Key('submit_retry')), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(c.marks, hasLength(5));
    });
  });

  group('school-day gate', () {
    const reason = 'Sun Oct 25 2026 is a weekend day under this school\'s configured school days (mon, tue)';
    const closed = SchoolDayStatus(valid: false, configured: true, reason: reason);

    testWidgets('valid day: no banner, Mark remaining present available (single-class teacher unchanged)', (t) async {
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('school_day_banner')), findsNothing);
      expect(find.byKey(const Key('mark_remaining_present')), findsOneWidget);
      expect(find.byKey(const Key('class_bar')), findsNothing);
    });

    testWidgets('unknown (check failed): no banner, marking works', (t) async {
      attendance.checkResult = (_, __) async => const SchoolDayStatus.unknown();
      await boot(t, const AttendanceMarkScreen());
      expect(find.byKey(const Key('school_day_banner')), findsNothing);
      expect(find.byKey(const Key('mark_remaining_present')), findsOneWidget);
    });

    testWidgets('closed day: reason banner with Check again, no bulk-mark, submit disabled; Check again unblocks', (t) async {
      attendance.checkResult = (_, __) async => closed;
      await boot(t, const AttendanceMarkScreen());
      await t.pump();
      expect(find.byKey(const Key('school_day_banner')), findsOneWidget);
      expect(find.text('No attendance today: $reason'), findsOneWidget);
      expect(find.byKey(const Key('school_day_recheck')), findsOneWidget);
      expect(find.byKey(const Key('mark_remaining_present')), findsNothing);
      expect(t.widget<EmPrimaryButton>(find.byKey(const Key('submit_button'))).onPressed, isNull);
      attendance.checkResult = (_, __) async => const SchoolDayStatus(valid: true);
      await t.tap(find.byKey(const Key('school_day_recheck')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('school_day_banner')), findsNothing);
      expect(find.byKey(const Key('mark_remaining_present')), findsOneWidget);
    });

    testWidgets('a save rejected as not-a-school-day shows the server message, the banner and keeps the marks', (t) async {
      const msg = 'Cannot mark attendance: 2026-10-05 is a holiday: Eid';
      attendance.onSubmit = (_, __) async => throw ApiException(msg, statusCode: 400);
      await boot(t, const AttendanceMarkScreen());
      await t.tap(find.byKey(const Key('mark_remaining_present')));
      await t.pump();
      await t.tap(find.byKey(const Key('submit_button')));
      await t.pump();
      await t.tap(find.byKey(const Key('attendance_confirm_submit')));
      await t.pump();
      await t.pump();
      expect(find.text(msg), findsOneWidget); // snack, verbatim
      expect(find.text('No attendance today: 2026-10-05 is a holiday: Eid'), findsOneWidget);
      expect(find.byKey(const Key('school_day_recheck')), findsOneWidget);
      expect(find.byKey(const Key('submit_error_banner')), findsNothing);
      expect(c.marks, hasLength(roster.length));
    });

    testWidgets('stale class + closed day: both banners render and submit stays disabled', (t) async {
      final two = [
        {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'A', 'name': 'Grade 5 - A'},
        {'gradeId': 'g5', 'gradeName': 'Grade 5', 'sectionName': 'B', 'name': 'Grade 5 - B'},
      ];
      attendance.checkResult = (_, __) async => closed;
      await boot(t, const AttendanceMarkScreen(), assignments: two, token: classTeacherJwt([(grade: 'Grade 5', section: 'A')]));
      await t.tap(find.byKey(const ValueKey('class_chip_5|b')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stale_class_banner')), findsOneWidget);
      expect(find.byKey(const Key('school_day_banner')), findsOneWidget);
      expect(c.canSubmit, isFalse);
      expect(t.widget<EmPrimaryButton>(find.byKey(const Key('submit_button'))).onPressed, isNull);
    });
  });
}

WidgetTester tester(WidgetTester t) => t;
