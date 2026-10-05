import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_history_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_history_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_mark_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_screen.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';

void main() {
  late FakeStudentsRepository students;
  late FakeAttendanceRepository attendance;
  late AttendanceController c;
  final now = DateTime(2026, 10, 5, 9);
  final roster = [for (var i = 1; i <= 5; i++) student(i)];

  setUp(() {
    Get.reset();
    Get.testMode = true;
    students = FakeStudentsRepository()..roster = (_) async => roster;
    attendance = FakeAttendanceRepository();
  });
  tearDown(Get.reset);

  Future<void> boot(WidgetTester t, Widget screen, {bool classTeacher = true, bool tall = true}) async {
    final h = (await t.runAsync(() => signedIn(classTeacher: classTeacher)))!;
    c = AttendanceController(students: students, attendance: attendance, auth: h.auth, permissions: h.perms, clock: () => now);
    Get.put(c);
    Get.put(AttendanceHistoryController(attendance: attendance, daily: c, clock: () => now));
    if (tall) {
      await t.binding.setSurfaceSize(const Size(430, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
    }
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: screen));
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
      attendance.onSubmit = (_, __) async => throw ApiException('Access denied. You are the class teacher of your own assigned class only.', statusCode: 403);
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
      expect(tester(t).widget<ElevatedButton>(find.byKey(const Key('submit_button'))).onPressed, isNull);
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
}

WidgetTester tester(WidgetTester t) => t;
