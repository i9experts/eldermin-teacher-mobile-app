import 'attendance_models.dart';

/// One calendar day of the class register, built from `attendance/list` rows.
class DayAttendance {
  /// `YYYY-MM-DD`.
  final String dayKey;
  /// Status of each student who has an in-enum record that day.
  final Map<String, AttendanceStatus> byStudent;
  /// Students with a record whose status is outside the enum (counted as marked, shown as "other").
  final int other;
  final int rosterSize;

  const DayAttendance({required this.dayKey, this.byStudent = const {}, this.other = 0, this.rosterSize = 0});

  StatusCounts get counts => StatusCounts.fromStatuses([...byStudent.values, for (var i = 0; i < other; i++) null]);

  /// Students with any record that day.
  int get marked => byStudent.length + other;

  bool get complete => rosterSize > 0 && marked >= rosterSize;
}

enum DayTone { none, allPresent, attention, absences }

extension DayAttendanceTone on DayAttendance {
  /// Calendar marker colour: absences > any late/leave/half-day > all present.
  DayTone get tone {
    final c = counts;
    if (marked == 0) return DayTone.none;
    if (c.absent > 0) return DayTone.absences;
    if (c.late + c.excused + c.halfDay + c.other > 0) return DayTone.attention;
    return DayTone.allPresent;
  }
}

/// A month of the register keyed by day.
class MonthAttendance {
  final Map<String, DayAttendance> days;
  final int rosterSize;
  const MonthAttendance({this.days = const {}, this.rosterSize = 0});

  DayAttendance? day(String key) => days[key];

  /// Groups [records] by calendar day (timezone-agnostic, [AttendanceRecord.dayKey]); records of students
  /// outside [rosterIds] (moved/left, other section) are ignored; two records for one student/day (should not
  /// exist: unique index {studentId,date}) keep the last one.
  factory MonthAttendance.build(Iterable<AttendanceRecord> records, Set<String> rosterIds) {
    final byDay = <String, Map<String, AttendanceRecord>>{};
    for (final r in records) {
      final k = r.dayKey;
      if (k == null || !rosterIds.contains(r.studentId)) continue;
      (byDay[k] ??= {})[r.studentId] = r;
    }
    final days = <String, DayAttendance>{};
    byDay.forEach((k, perStudent) {
      final by = <String, AttendanceStatus>{};
      var other = 0;
      perStudent.forEach((id, r) {
        final s = r.status;
        if (s == null) {
          other++;
        } else {
          by[id] = s;
        }
      });
      days[k] = DayAttendance(dayKey: k, byStudent: by, other: other, rosterSize: rosterIds.length);
    });
    return MonthAttendance(days: days, rosterSize: rosterIds.length);
  }
}
