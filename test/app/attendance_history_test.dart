import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_history_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_month.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonthAttendance.build', () {
    final s = [for (var i = 1; i <= 5; i++) student(i)];
    final ids = {for (final x in s) x.id};
    DateTime at(int d) => DateTime.utc(2026, 10, d);

    test('groups by calendar day, counts statuses, marks tone and completeness', () {
      final m = MonthAttendance.build([
        for (final x in s) record(x, at(1), 'present'), // all present, complete
        record(s[0], at(2), 'present'), record(s[1], at(2), 'late'), // partial + attention
        for (final x in s) record(x, at(5), x == s[2] ? 'absent' : 'present'), // absences
      ], ids);
      final d1 = m.day('2026-10-01')!;
      expect((d1.marked, d1.complete, d1.tone), (5, true, DayTone.allPresent));
      final d2 = m.day('2026-10-02')!;
      expect((d2.marked, d2.complete, d2.tone), (2, false, DayTone.attention));
      expect(d2.counts.late, 1);
      final d5 = m.day('2026-10-05')!;
      expect((d5.counts.absent, d5.counts.present, d5.tone), (1, 4, DayTone.absences));
      expect(m.day('2026-10-03'), isNull);
      expect(m.rosterSize, 5);
    });

    test('ignores students outside the roster, undated rows; unknown statuses count as "other"; duplicates keep the last', () {
      final m = MonthAttendance.build([
        record(student(77), at(1), 'absent'),
        const AttendanceRecord(studentId: 'x'),
        record(s[0], at(1), 'holiday'),
        record(s[1], at(1), 'absent'),
        record(s[1], at(1), 'present'),
      ], ids);
      final d = m.day('2026-10-01')!;
      expect(d.other, 1);
      expect(d.byStudent[s[1].id], AttendanceStatus.present);
      expect(d.marked, 2);
      expect(d.tone, DayTone.attention);
    });

    test('server offsets: UTC+5 local midnight and UTC-7 local midnight land on the right day', () {
      final m = MonthAttendance.build([
        record(s[0], DateTime.utc(2026, 10, 4, 19), 'present'), // Karachi midnight of the 5th
        record(s[1], DateTime.utc(2026, 10, 5, 7), 'present'), // Los Angeles midnight of the 5th
      ], ids);
      expect(m.days.keys, ['2026-10-05']);
      expect(m.day('2026-10-05')!.marked, 2);
    });
  });

  group('AttendanceHistoryController', () {
    late FakeStudentsRepository students;
    late FakeAttendanceRepository attendance;
    late DateTime now;
    final roster = [for (var i = 1; i <= 3; i++) student(i)];

    setUp(() {
      Get.reset();
      Get.testMode = true;
      students = FakeStudentsRepository()..roster = (_) async => roster;
      attendance = FakeAttendanceRepository();
      now = DateTime(2026, 10, 5, 9);
    });
    tearDown(Get.reset);

    Future<AttendanceHistoryController> make({bool classTeacher = true}) async {
      final h = await signedIn(classTeacher: classTeacher);
      final daily = AttendanceController(students: students, attendance: attendance, auth: h.auth, permissions: h.perms, clock: () => now);
      return AttendanceHistoryController(attendance: attendance, daily: daily, clock: () => now);
    }

    test('requests the whole month with the class strings, loads the roster on demand, builds day summaries', () async {
      attendance.range = (_, __, first, last) async => first == last
          ? <AttendanceRecord>[]
          : [
              record(roster[0], DateTime.utc(2026, 10, 1), 'present'),
              record(roster[1], DateTime.utc(2026, 10, 1), 'absent'),
              record(roster[2], DateTime.utc(2026, 10, 1), 'present'),
            ];
      final c = await make();
      await c.loadMonth();
      final monthCall = attendance.rangeCalls.last;
      expect((monthCall.grade, monthCall.section), ('Grade 5', 'A'));
      expect(monthCall.first, DateTime(2026, 10, 1));
      expect(monthCall.last, DateTime(2026, 10, 31));
      expect(students.calls, contains('roster:Grade 5 - A'));
      final m = c.month.value.data!;
      expect(m.day('2026-10-01')!.counts.absent, 1);
      expect(m.day('2026-10-01')!.complete, isTrue);
    });

    test('day selection, edit window and "future" rules', () async {
      final c = await make();
      await c.loadMonth();
      c.selectDay(DateTime(2026, 10, 5));
      expect(c.canEditSelected, isTrue);
      c.selectDay(DateTime(2026, 9, 20));
      expect(c.canEditSelected, isFalse);
      c.selectDay(DateTime(2026, 10, 28));
      expect(c.canEditSelected, isFalse);
      expect(c.selected, isNull);
    });

    test('focusMonth moves back, reloads that month, never past the current month', () async {
      final c = await make();
      await c.loadMonth();
      c.focusMonth(DateTime(2026, 9, 1));
      await Future<void>.delayed(Duration.zero);
      expect(attendance.rangeCalls.last.first, DateTime(2026, 9, 1));
      expect(attendance.rangeCalls.last.last, DateTime(2026, 9, 30));
      final before = attendance.rangeCalls.length;
      c.focusMonth(DateTime(2026, 11, 1));
      expect(c.focusedMonth.value, DateTime(2026, 9, 1));
      expect(attendance.rangeCalls.length, before);
      expect(c.isCurrentMonth, isFalse);
    });

    test('errors: month request 500 -> error; 403 -> forbidden; roster 403 surfaces; reload recovers', () async {
      final c = await make();
      attendance.range = (_, __, first, last) async => first == last ? [] : throw ApiException('x', statusCode: 500);
      await c.loadMonth();
      expect(c.month.value.status, SectionStatus.error);
      attendance.range = (_, __, first, last) async => first == last ? [] : throw ApiException('Forbidden', statusCode: 403);
      await c.loadMonth();
      expect(c.month.value.status, SectionStatus.forbidden);
      attendance.range = (_, __, ___, ____) async => [];
      await c.reload();
      expect(c.month.value.status, SectionStatus.data);

      Get.reset();
      Get.testMode = true;
      students = FakeStudentsRepository()..roster = (_) async => throw ApiException('Forbidden', statusCode: 403);
      final c2 = await make();
      await c2.loadMonth();
      expect(c2.month.value.status, SectionStatus.forbidden);
    });

    test('not a class teacher: nothing is requested', () async {
      final c = await make(classTeacher: false);
      await c.loadMonth();
      expect(attendance.rangeCalls, isEmpty);
    });
  });
}
