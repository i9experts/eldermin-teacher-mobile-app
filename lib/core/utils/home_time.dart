import '../models/home/timetable.dart';

/// Injectable clock: every date/time rule below takes `now` explicitly (or a
/// [Clock]) so tests never depend on the wall clock.
typedef Clock = DateTime Function();

/// Backend day index: 0 = Sunday .. 6 = Saturday (JS `Date.getDay()`,
/// timetable.schema.ts:19). Dart weekday is Mon=1..Sun=7.
int dayIndexOf(DateTime d) => d.weekday % 7;

/// Parses "HH:mm" (also "H:mm" / "HH:mm:ss") to minutes after midnight.
/// Returns null for anything else (legacy rows are not validated: U7/U8).
int? parseHm(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 24 || min > 59) return null;
  return h * 60 + min;
}

/// Minutes after midnight -> zero-padded "HH:mm".
String formatHm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "Good morning" (05:00-11:59), "Good afternoon" (12:00-16:59), else "Good evening".
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// `yyyy-MM-dd` of the LOCAL calendar date (used to detect midnight rollover).
String dateKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'
];

/// "Monday, 5 October" (local device date).
String longDateOf(DateTime d) => '${_weekdays[dayIndexOf(d)]}, ${d.day} ${_months[d.month - 1]}';

/// The UTC window covering the device's LOCAL calendar date, for server
/// filters on `date` (attendance `from`/`to`, fixtures `from`/`to`). Stored
/// dates are midnight of the date string the writer sent, so a whole-day
/// range is safer than equality (shapes doc sections 2a and 6).
({DateTime from, DateTime to}) todayRangeUtc(DateTime now) => (
      from: DateTime.utc(now.year, now.month, now.day),
      to: DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999),
    );

enum PeriodPhase { past, current, next, later }

/// One period this teacher teaches, flattened out of the whole-class
/// timetable documents.
class TeacherPeriod {
  final int day;
  final int? periodNo;
  final int? startMinutes;
  final int? endMinutes;
  final String startText;
  final String endText;
  final String classLabel;
  final String subject;
  final String room;
  final String type;

  /// 'A' / 'B' only when the class runs a week cycle AND the period is
  /// cycle-specific; null otherwise. We never decide which week is current
  /// (U1: `cycleAnchor` semantics are unverified), we only label it.
  final String? weekCycleTag;

  /// Group label when the teacher teaches one group of a split lesson.
  final String? splitLabel;

  const TeacherPeriod({
    required this.day,
    this.periodNo,
    this.startMinutes,
    this.endMinutes,
    this.startText = '',
    this.endText = '',
    this.classLabel = '',
    this.subject = '',
    this.room = '',
    this.type = 'regular',
    this.weekCycleTag,
    this.splitLabel,
  });

  String get timeRange => startMinutes != null && endMinutes != null
      ? '${formatHm(startMinutes!)} - ${formatHm(endMinutes!)}'
      : [startText, endText].where((e) => e.isNotEmpty).join(' - ');

  String get _dedupeKey =>
      '$day|$startText|$endText|$classLabel|$subject|${weekCycleTag ?? ''}|${splitLabel ?? ''}';
}

/// A [TeacherPeriod] with its position relative to "now".
class TodayPeriod {
  final TeacherPeriod period;
  final PeriodPhase phase;
  const TodayPeriod(this.period, this.phase);
}

/// Keeps ONLY this teacher's periods (top-level teacherId or a split group,
/// as the web does) and flattens them. Duplicate rows from duplicate active
/// timetables for one class (U6) are collapsed.
List<TeacherPeriod> teacherPeriodsOf(List<TimetableDoc> docs, String staffId) {
  if (staffId.isEmpty) return const [];
  final seen = <String>{};
  final out = <TeacherPeriod>[];
  for (final doc in docs) {
    for (final p in doc.periods) {
      if (p.day == null || !p.isTeachingBy(staffId)) continue;
      final group = p.teacherId == staffId ? null : p.splitGroupOf(staffId);
      final start = parseHm(p.startTime), end = parseHm(p.endTime);
      final tag = doc.weekCycleEnabled && (p.weekCycle == 'A' || p.weekCycle == 'B') ? p.weekCycle : null;
      final tp = TeacherPeriod(
        day: p.day!,
        periodNo: p.periodNo,
        startMinutes: start,
        endMinutes: end,
        startText: p.startTime,
        endText: p.endTime,
        classLabel: doc.classLabel,
        subject: p.subject,
        room: group != null && group.roomNo.isNotEmpty ? group.roomNo : p.roomNo,
        type: p.type,
        weekCycleTag: tag,
        splitLabel: group == null ? null : (group.label.isEmpty ? 'Split group' : group.label),
      );
      if (seen.add(tp._dedupeKey)) out.add(tp);
    }
  }
  return out;
}

/// Flattens the `GET /staff-portal/timetable` response into [TeacherPeriod]s. The server already
/// filtered to MY slots, so no teacher filtering happens here. Slots keep their own `both|A|B` tag:
/// 'A'/'B' become the "Week A/B" tag, 'both' stays untagged; the day-level `weekCycle` (always null,
/// U1) is ignored - which week is current is never guessed. A split slot carries its group name.
List<TeacherPeriod> teacherPeriodsFromTimetable(MyTimetable t) {
  final out = <TeacherPeriod>[];
  for (final d in t.days) {
    final day = d.dayOfWeek ?? _dayOfDateString(d.date);
    if (day == null) continue;
    for (final s in d.slots) {
      final g = s.splitGroup;
      out.add(TeacherPeriod(
        day: day,
        periodNo: s.periodNo,
        startMinutes: parseHm(s.startTime),
        endMinutes: parseHm(s.endTime),
        startText: s.startTime,
        endText: s.endTime,
        classLabel: s.classLabel,
        subject: s.subject,
        room: s.roomNo,
        type: s.type,
        weekCycleTag: (s.weekCycle == 'A' || s.weekCycle == 'B') ? s.weekCycle : null,
        splitLabel: g == null ? null : (g.name.isEmpty ? 'Split group' : g.name),
      ));
    }
  }
  return out;
}

int? _dayOfDateString(String ymd) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(ymd);
  if (m == null) return null;
  return DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)).weekday % 7;
}

/// This teacher's periods on [day] (0=Sun..6=Sat), ordered by start time.
/// Periods whose time cannot be read sort last.
List<TeacherPeriod> periodsOnDay(List<TeacherPeriod> all, int day) {
  final list = all.where((p) => p.day == day).toList();
  list.sort((a, b) {
    final x = a.startMinutes ?? 1 << 20, y = b.startMinutes ?? 1 << 20;
    final c = x.compareTo(y);
    return c != 0 ? c : (a.periodNo ?? 0).compareTo(b.periodNo ?? 0);
  });
  return list;
}

/// Marks each of today's [periods] as past / current / next / later at [now].
/// current: start <= now < end. next: the earliest start strictly after now
/// (ties, e.g. week A and B in the same slot, are all "next"). A period whose
/// time cannot be parsed is never current/next.
List<TodayPeriod> annotatePeriods(List<TeacherPeriod> periods, DateTime now) {
  final nowMin = now.hour * 60 + now.minute;
  int? nextStart;
  for (final p in periods) {
    final s = p.startMinutes;
    if (s != null && s > nowMin && (nextStart == null || s < nextStart)) nextStart = s;
  }
  return [
    for (final p in periods)
      TodayPeriod(
        p,
        () {
          final s = p.startMinutes, e = p.endMinutes;
          if (s == null) return PeriodPhase.later;
          if (e != null && s <= nowMin && nowMin < e) return PeriodPhase.current;
          if (s > nowMin) return s == nextStart ? PeriodPhase.next : PeriodPhase.later;
          return PeriodPhase.past;
        }(),
      ),
  ];
}

/// Convenience: today's annotated periods for the device-local [now].
List<TodayPeriod> todayPeriods(List<TeacherPeriod> all, DateTime now) =>
    annotatePeriods(periodsOnDay(all, dayIndexOf(now)), now);

/// "10 Oct" for a date the backend stores as a UTC calendar date (PTM, fixtures).
String shortUtcDateOf(DateTime d) {
  final u = d.toUtc();
  return '${u.day} ${_months[u.month - 1].substring(0, 3)}';
}
