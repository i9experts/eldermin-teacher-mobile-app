import '../json_helpers.dart';

/// `GET /students/class-roster-diagnostic` (students.service.ts:478-513, verified).
class RosterCount {
  final int totalInClass;
  final int activeCount;
  const RosterCount({this.totalInClass = 0, this.activeCount = 0});

  factory RosterCount.fromJson(Map<String, dynamic> j) => RosterCount(
        totalInClass: readInt(j['totalInClass']) ?? 0,
        activeCount: readInt(j['activeCount']) ?? 0,
      );
}

/// `meta.total` of `GET /students/attendance/list` (students.service.ts:1851, verified).
int attendanceTotalFromJson(Map<String, dynamic> j) => readInt(asJsonMap(j['meta'])['total']) ?? 0;

enum AttendanceMarkState { notMarked, partial, complete }

/// The class-teacher card: roster size + whether today's attendance exists.
class ClassAttendanceSnapshot {
  final String label;
  final String grade;
  final String section;
  final int rosterSize;
  final int markedCount;

  const ClassAttendanceSnapshot({
    required this.label,
    required this.grade,
    required this.section,
    required this.rosterSize,
    required this.markedCount,
  });

  /// No dedicated endpoint exists: "marked" = at least one record for today;
  /// "partial" = fewer records than the active roster.
  AttendanceMarkState get state {
    if (markedCount <= 0) return AttendanceMarkState.notMarked;
    if (rosterSize > 0 && markedCount < rosterSize) return AttendanceMarkState.partial;
    return AttendanceMarkState.complete;
  }

  int get percent {
    if (rosterSize <= 0) return markedCount > 0 ? 100 : 0;
    return ((markedCount / rosterSize) * 100).round().clamp(0, 100);
  }
}
