import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:eldermin_teacher_app/core/utils/timetable_week.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device wall clock (what `DateTime.now()` shows in a given zone) for a UTC instant. The logic under
/// test must use ONLY the wall-clock fields, so a fixed offset per zone is a faithful emulation.
DateTime wall(DateTime utc, Duration offset) {
  final w = utc.add(offset);
  return DateTime(w.year, w.month, w.day, w.hour, w.minute);
}

const zones = <String, Duration>{
  'UTC': Duration.zero,
  'Pacific/Auckland (NZDT +13)': Duration(hours: 13),
  'America/Los_Angeles (PDT -7)': Duration(hours: -7),
  'Asia/Karachi (+5)': Duration(hours: 5),
};

TeacherPeriod tp(int day, String s, String e, {String subject = 'Maths', String? tag}) => TeacherPeriod(
    day: day, periodNo: 1, startMinutes: parseHm(s), endMinutes: parseHm(e), startText: s, endText: e,
    classLabel: 'Grade 5 - A', subject: subject, weekCycleTag: tag);

void main() {
  group('week helpers', () {
    test('weeks run Sunday..Saturday', () {
      expect(weekStartOf(DateTime(2026, 10, 5)), DateTime(2026, 10, 4)); // Mon -> Sun
      expect(weekStartOf(DateTime(2026, 10, 4)), DateTime(2026, 10, 4)); // Sun -> itself
      expect(weekStartOf(DateTime(2026, 10, 10)), DateTime(2026, 10, 4)); // Sat -> Sun
      expect(weekStartOf(DateTime(2026, 10, 11)), DateTime(2026, 10, 11));
      final days = weekDaysFrom(DateTime(2026, 10, 4));
      expect(days.map((d) => weekdayShort(d)), ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
      expect(days.map((d) => dayIndexOf(d)), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('week crossing a month and a year boundary', () {
      expect(weekStartOf(DateTime(2026, 3, 2)), DateTime(2026, 3, 1));
      expect(weekStartOf(DateTime(2026, 1, 1)), DateTime(2025, 12, 28));
      expect(weekDaysFrom(DateTime(2025, 12, 28)).last, DateTime(2026, 1, 3));
      expect(weekRangeLabel(DateTime(2026, 10, 4)), '4 - 10 Oct');
      expect(weekRangeLabel(DateTime(2026, 9, 27)), '27 Sep - 3 Oct');
      expect(addDays(DateTime(2026, 2, 27), 3), DateTime(2026, 3, 2));
      expect(dayMonthShort(DateTime(2026, 10, 5)), '5 Oct');
    });

    test('DST transition weeks keep seven distinct calendar days (no 23/25h drift)', () {
      for (final start in [DateTime(2026, 3, 8), DateTime(2026, 10, 25), DateTime(2026, 11, 1), DateTime(2026, 9, 27)]) {
        final days = weekDaysFrom(start);
        expect(days.map((d) => d.day).toSet(), hasLength(7));
        expect(days.every((d) => d.hour == 0), isTrue);
      }
    });

    for (final z in zones.entries) {
      test('${z.key}: "today", its week and the current period come from the wall clock only', () {
        // 2026-10-10 20:00Z: Saturday in UTC and LA, already Sunday 11 Oct in Auckland and Karachi.
        final now = wall(DateTime.utc(2026, 10, 10, 20), z.value);
        final sunday = now.weekday == DateTime.sunday;
        expect(dayIndexOf(now), sunday ? 0 : 6);
        expect(weekStartOf(now), sunday ? DateTime(2026, 10, 11) : DateTime(2026, 10, 4));
        final all = [tp(dayIndexOf(now), '${now.hour.toString().padLeft(2, '0')}:00', '${(now.hour + 1).toString().padLeft(2, '0')}:00')];
        final items = periodsForDate(all, dateOnly(now), now);
        expect(items.single.phase, PeriodPhase.current, reason: 'wall clock ${now.hour}:${now.minute}');
        // another date never gets a phase even when its weekday matches
        final other = periodsForDate(all, addDays(dateOnly(now), 7), now);
        expect(other.single.phase, PeriodPhase.later);
      });
    }

    test('NOW / NEXT / past only for today; other dates are phase-free', () {
      final all = [tp(1, '08:00', '08:45'), tp(1, '09:00', '09:45'), tp(1, '14:00', '14:45')];
      final now = DateTime(2026, 10, 5, 8, 10);
      final today = periodsForDate(all, DateTime(2026, 10, 5), now);
      expect(today.map((e) => e.phase), [PeriodPhase.current, PeriodPhase.next, PeriodPhase.later]);
      final nextMonday = periodsForDate(all, DateTime(2026, 10, 12), now);
      expect(nextMonday.map((e) => e.phase).toSet(), {PeriodPhase.later});
      final yesterday = periodsForDate([tp(0, '08:00', '08:45')], DateTime(2026, 10, 4), now);
      expect(yesterday.single.phase, PeriodPhase.later);
    });

    test('empty day and week tags', () {
      expect(periodsForDate([tp(2, '08:00', '08:45')], DateTime(2026, 10, 5), DateTime(2026, 10, 5, 9)), isEmpty);
      expect(hasWeekTags([tp(1, '08:00', '08:45')]), isFalse);
      expect(hasWeekTags([tp(1, '08:00', '08:45', tag: 'A')]), isTrue);
    });

    test('A and B variants of one slot are both listed (never guessed)', () {
      final all = [tp(1, '12:30', '13:15', subject: 'Science', tag: 'A'), tp(1, '12:30', '13:15', subject: 'Science (rev)', tag: 'B')];
      final items = periodsForDate(all, DateTime(2026, 10, 5), DateTime(2026, 10, 5, 12, 40));
      expect(items, hasLength(2));
      expect(items.map((e) => e.period.weekCycleTag), ['A', 'B']);
      expect(items.map((e) => e.phase).toSet(), {PeriodPhase.current}); // both are "now": we do not pick one
    });
  });
}
