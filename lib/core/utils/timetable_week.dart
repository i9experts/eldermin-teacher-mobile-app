import 'home_time.dart';

/// Pure calendar helpers for the Timetable module. Everything works on the
/// LOCAL calendar fields (year/month/day, hour/minute) of the dates it is
/// given and never converts to UTC, so the device zone cannot shift a day
/// (DST included: dates are rebuilt with `DateTime(y, m, d + n)`).

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Sunday of the week containing [d] (weeks run Sun..Sat, matching the
/// backend day index 0 = Sunday, timetable.schema.ts:19).
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday % 7));

/// Sunday..Saturday starting at [start].
List<DateTime> weekDaysFrom(DateTime start) =>
    [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

const _short = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String weekdayShort(DateTime d) => _short[dayIndexOf(d)];

String dayMonthShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "4 - 10 Oct" or "28 Sep - 4 Oct" for the week starting at [start].
String weekRangeLabel(DateTime start) {
  final end = addDays(start, 6);
  final from = start.month == end.month ? '${start.day}' : dayMonthShort(start);
  return '$from - ${dayMonthShort(end)}';
}

/// The periods of [date], ordered by start time. The NOW/NEXT/past phases are
/// computed ONLY when [date] is the same calendar date as [now]; any other
/// date is listed without a phase (it is neither past nor upcoming "right now").
List<TodayPeriod> periodsForDate(List<TeacherPeriod> all, DateTime date, DateTime now) {
  final periods = periodsOnDay(all, dayIndexOf(date));
  if (sameDate(date, now)) return annotatePeriods(periods, now);
  return [for (final p in periods) TodayPeriod(p, PeriodPhase.later)];
}

/// True when any period carries a Week A / Week B tag (so the screen explains it).
bool hasWeekTags(List<TeacherPeriod> all) => all.any((p) => p.weekCycleTag != null);
