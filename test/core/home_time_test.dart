import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:flutter_test/flutter_test.dart';

TimetablePeriod p(int day, String s, String e,
        {String teacher = 'me', String week = 'both', List<SplitGroup> splits = const [], String room = '1', int no = 1}) =>
    TimetablePeriod(day: day, periodNo: no, startTime: s, endTime: e, subject: 'Maths', teacherId: teacher, roomNo: room, weekCycle: week, splitGroups: splits);

TimetableDoc doc(List<TimetablePeriod> ps, {bool cycle = false, String id = 'd1'}) =>
    TimetableDoc(id: id, gradeLevel: 'Grade 5', sectionName: 'A', weekCycleEnabled: cycle, periods: ps);

void main() {
  test('dayIndexOf: Sunday=0 .. Saturday=6 (backend getDay)', () {
    expect(dayIndexOf(DateTime(2026, 10, 4)), 0); // Sunday
    expect(dayIndexOf(DateTime(2026, 10, 5)), 1); // Monday
    expect(dayIndexOf(DateTime(2026, 10, 10)), 6); // Saturday
  });

  test('parseHm / formatHm', () {
    expect(parseHm('08:05'), 485);
    expect(parseHm('8:05'), 485);
    expect(parseHm('08:05:30'), 485);
    expect(parseHm('25:00'), isNull);
    expect(parseHm('08.05'), isNull);
    expect(parseHm(''), isNull);
    expect(parseHm(null), isNull);
    expect(formatHm(485), '08:05');
    expect(formatHm(0), '00:00');
  });

  test('greeting by time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 11, 59)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 17)), 'Good evening');
    expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Good evening');
  });

  test('longDateOf / dateKeyOf / shortUtcDateOf', () {
    expect(longDateOf(DateTime(2026, 10, 5, 23, 59)), 'Monday, 5 October');
    expect(dateKeyOf(DateTime(2026, 3, 4)), '2026-03-04');
    expect(shortUtcDateOf(DateTime.utc(2026, 10, 10)), '10 Oct');
  });

  test('midnight rollover changes the date key and the day index', () {
    final before = DateTime(2026, 10, 5, 23, 59, 59);
    final after = before.add(const Duration(seconds: 1));
    expect(dateKeyOf(before), isNot(dateKeyOf(after)));
    expect(dayIndexOf(before), 1);
    expect(dayIndexOf(after), 2);
  });

  test('todayRangeUtc covers the local calendar date as UTC bounds', () {
    final r = todayRangeUtc(DateTime(2026, 10, 5, 23, 59));
    expect(r.from, DateTime.utc(2026, 10, 5));
    expect(r.to, DateTime.utc(2026, 10, 5, 23, 59, 59, 999));
  });

  group('teacherPeriodsOf', () {
    test('keeps only this teacher (top-level or split group), drops others', () {
      final d = doc([
        p(1, '08:00', '08:45'),
        p(1, '09:00', '09:45', teacher: 'other'),
        p(1, '10:00', '10:45', teacher: '', splits: const [
          SplitGroup(label: 'G1', teacherId: 'me', roomNo: 'Lab 1'),
          SplitGroup(label: 'G2', teacherId: 'other', roomNo: 'Lab 2'),
        ]),
        p(1, '11:00', '11:45', teacher: ''),
      ]);
      final out = teacherPeriodsOf([d], 'me');
      expect(out.map((e) => e.startText), ['08:00', '10:00']);
      expect(out[1].room, 'Lab 1');
      expect(out[1].splitLabel, 'G1');
      expect(out[0].classLabel, 'Grade 5 - A');
    });

    test('empty staffId yields nothing (never show whole-class data)', () {
      expect(teacherPeriodsOf([doc([p(1, '08:00', '08:45')])], ''), isEmpty);
    });

    test('duplicate active timetables collapse (U6)', () {
      final a = doc([p(1, '08:00', '08:45')], id: 'a');
      final b = doc([p(1, '08:00', '08:45')], id: 'b');
      expect(teacherPeriodsOf([a, b], 'me'), hasLength(1));
    });

    test('week-cycle tag only when the class runs a cycle (no guessing A/B)', () {
      final on = teacherPeriodsOf([doc([p(1, '08:00', '08:45', week: 'A')], cycle: true)], 'me');
      final off = teacherPeriodsOf([doc([p(1, '08:00', '08:45', week: 'A')])], 'me');
      final both = teacherPeriodsOf([doc([p(1, '08:00', '08:45')], cycle: true)], 'me');
      expect(on.single.weekCycleTag, 'A');
      expect(off.single.weekCycleTag, isNull);
      expect(both.single.weekCycleTag, isNull);
    });
  });

  group('current / next', () {
    final all = teacherPeriodsOf([
      doc([
        p(1, '08:00', '08:45', no: 1),
        p(1, '10:00', '10:45', no: 3),
        p(1, '09:00', '09:45', no: 2),
        p(2, '08:00', '08:45', no: 1),
      ])
    ], 'me');
    List<PeriodPhase> phases(DateTime now) => todayPeriods(all, now).map((e) => e.phase).toList();

    test('before the first period: first is next', () {
      expect(phases(DateTime(2026, 10, 5, 7, 0)), [PeriodPhase.next, PeriodPhase.later, PeriodPhase.later]);
    });
    test('inside a period: current, following is next', () {
      expect(phases(DateTime(2026, 10, 5, 9, 10)), [PeriodPhase.past, PeriodPhase.current, PeriodPhase.next]);
    });
    test('boundaries: start inclusive, end exclusive', () {
      expect(phases(DateTime(2026, 10, 5, 8, 0)).first, PeriodPhase.current);
      expect(phases(DateTime(2026, 10, 5, 8, 45)).first, PeriodPhase.past);
    });
    test('between periods: next only', () {
      expect(phases(DateTime(2026, 10, 5, 9, 50)), [PeriodPhase.past, PeriodPhase.past, PeriodPhase.next]);
    });
    test('after the last period: all past', () {
      expect(phases(DateTime(2026, 10, 5, 18, 0)), everyElement(PeriodPhase.past));
    });
    test('ordered by start time regardless of input order', () {
      expect(todayPeriods(all, DateTime(2026, 10, 5, 12)).map((e) => e.period.startText), ['08:00', '09:00', '10:00']);
    });
    test('empty day (Wednesday) -> empty list', () {
      expect(todayPeriods(all, DateTime(2026, 10, 7, 9)), isEmpty);
    });
    test('Sunday (index 0) works', () {
      final sun = teacherPeriodsOf([doc([p(0, '09:00', '09:30')])], 'me');
      expect(todayPeriods(sun, DateTime(2026, 10, 4, 8)).single.phase, PeriodPhase.next);
      expect(todayPeriods(sun, DateTime(2026, 10, 5, 8)), isEmpty);
    });
    test('unparseable times never crash and are never current/next', () {
      final odd = teacherPeriodsOf([doc([p(1, 'soon', 'later')])], 'me');
      expect(todayPeriods(odd, DateTime(2026, 10, 5, 8)).single.phase, PeriodPhase.later);
    });
    test('A/B periods in one slot are both highlighted', () {
      final ab = teacherPeriodsOf([
        doc([p(1, '12:30', '13:15', week: 'A'), p(1, '12:30', '13:15', week: 'B', room: '2')], cycle: true)
      ], 'me');
      expect(todayPeriods(ab, DateTime(2026, 10, 5, 12, 40)).map((e) => e.phase), everyElement(PeriodPhase.current));
    });
  });
}
