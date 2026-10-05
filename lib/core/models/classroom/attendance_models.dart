import '../json_helpers.dart';

/// `status` enum of a student attendance record: present | absent | late |
/// excused | half_day (MarkAttendanceDto student.dto.ts:268; schema
/// student-supporting.schema.ts:25-29; verified).
enum AttendanceStatus {
  present('present', 'Present', 'P'),
  absent('absent', 'Absent', 'A'),
  late('late', 'Late', 'L'),
  excused('excused', 'Leave', 'E'),
  halfDay('half_day', 'Half day', 'H');

  final String wire;
  final String label;
  final String short;
  const AttendanceStatus(this.wire, this.label, this.short);

  /// Null for a value outside the enum (legacy rows): never coerced.
  static AttendanceStatus? fromWire(Object? v) {
    final s = v?.toString();
    for (final e in AttendanceStatus.values) {
      if (e.wire == s) return e;
    }
    return null;
  }
}

/// One `StudentAttendance` document (student-supporting.schema.ts:14-40).
/// Only the fields the app needs are kept.
class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String grade;
  final String section;
  /// Stored as SERVER-LOCAL midnight (students.service.ts:1800-1801); serialised
  /// as a UTC instant. Map to a calendar day with [attendanceDayKey], never `.toLocal()`.
  final DateTime? date;
  final AttendanceStatus? status;
  final String? rawStatus;
  final String? remarks;

  const AttendanceRecord({
    this.id = '',
    required this.studentId,
    this.studentName = '',
    this.grade = '',
    this.section = '',
    this.date,
    this.status,
    this.rawStatus,
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: readId(j['_id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        grade: readText(j['grade']),
        section: readText(j['section']),
        date: readDate(j['date']),
        status: AttendanceStatus.fromWire(j['status']),
        rawStatus: readString(j['status']),
        remarks: readString(j['remarks']),
      );

  /// `YYYY-MM-DD` calendar day of this record (timezone-agnostic, see [attendanceDayKey]).
  String? get dayKey => date == null ? null : attendanceDayKey(date!);
}

/// A page of `GET /students/attendance/list`: `{ data, meta:{total,page,limit,pages} }`
/// (students.service.ts:1851).
class AttendancePage {
  final List<AttendanceRecord> records;
  final int total;
  final int page;
  final int pages;
  const AttendancePage({this.records = const [], this.total = 0, this.page = 1, this.pages = 0});

  factory AttendancePage.fromJson(Map<String, dynamic> j) {
    final meta = asJsonMap(j['meta']);
    final recs = asJsonMapList(j['data']).map(AttendanceRecord.fromJson).toList();
    return AttendancePage(
      records: recs,
      total: readInt(meta['total']) ?? recs.length,
      page: readInt(meta['page']) ?? 1,
      pages: readInt(meta['pages']) ?? 0,
    );
  }
}

/// Counts per status for a day or a student.
class StatusCounts {
  final int present, absent, late, excused, halfDay, other;
  const StatusCounts({this.present = 0, this.absent = 0, this.late = 0, this.excused = 0, this.halfDay = 0, this.other = 0});

  int get total => present + absent + late + excused + halfDay + other;

  int of(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return present;
      case AttendanceStatus.absent:
        return absent;
      case AttendanceStatus.late:
        return late;
      case AttendanceStatus.excused:
        return excused;
      case AttendanceStatus.halfDay:
        return halfDay;
    }
  }

  factory StatusCounts.fromStatuses(Iterable<AttendanceStatus?> statuses) {
    var p = 0, a = 0, l = 0, e = 0, h = 0, o = 0;
    for (final s in statuses) {
      switch (s) {
        case AttendanceStatus.present:
          p++;
        case AttendanceStatus.absent:
          a++;
        case AttendanceStatus.late:
          l++;
        case AttendanceStatus.excused:
          e++;
        case AttendanceStatus.halfDay:
          h++;
        case null:
          o++;
      }
    }
    return StatusCounts(present: p, absent: a, late: l, excused: e, halfDay: h, other: o);
  }

  /// `GET /students/:id/attendance/summary` -> bare array `[{ _id: status, count }]`
  /// (students.service.ts:1859-1863). Also tolerates the 360's `{status: count}` map.
  factory StatusCounts.fromSummary(Object? body) {
    final counts = <String, int>{};
    if (body is List) {
      for (final row in asJsonMapList(body)) {
        final k = readString(row['_id']);
        if (k != null) counts[k] = (counts[k] ?? 0) + (readInt(row['count']) ?? 0);
      }
    } else if (body is Map) {
      body.forEach((k, v) => counts[k.toString()] = readInt(v) ?? 0);
    }
    return StatusCounts(
      present: counts['present'] ?? 0,
      absent: counts['absent'] ?? 0,
      late: counts['late'] ?? 0,
      excused: counts['excused'] ?? 0,
      halfDay: counts['half_day'] ?? 0,
      other: counts.entries
          .where((e) => AttendanceStatus.fromWire(e.key) == null)
          .fold(0, (a, e) => a + e.value),
    );
  }
}

// ── Dates ─────────────────────────────────────────────────────
//
// Backend facts (students.service.ts): the writer stores
// `date = new Date(dto.date); date.setHours(0,0,0,0)` = midnight in the SERVER's
// local zone (:1800-1801, :1812-1813); the reader filters `date >= new Date(from)`
// and `date <= new Date(to)` (:1842-1843). The server zone is UNVERIFIED (U3).
//
// The app is therefore timezone-agnostic by construction:
//  * WRITE `date` as noon UTC of the calendar day. For any server zone within
//    +-11h the instant falls on that calendar day in the server's zone, so
//    `setHours(0,0,0,0)` lands on that day's local midnight (a plain
//    `YYYY-MM-DD` = UTC midnight would land on the PREVIOUS day on a server
//    west of UTC). On a UTC server the stored value is identical to a
//    `YYYY-MM-DD` write.
//  * READ with the window [(D-1) 12:00Z, D 12:00Z] which contains day D's
//    local midnight for every server offset in (-12h, +12h) and no other day's.
//  * MAP a stored instant back to its day as the UTC date of (instant + 12h).

/// `YYYY-MM-DD` of a LOCAL calendar date (only y/m/d are used: the zone is irrelevant).
String ymdOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The calendar day (`YYYY-MM-DD`) a stored attendance instant belongs to.
String attendanceDayKey(DateTime instant) {
  final u = instant.toUtc().add(const Duration(hours: 12));
  return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
}

/// Value of `records[].date` for the calendar day [day] (y/m/d of [day] only).
String attendanceWireDate(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 12).toIso8601String();

/// `from`/`to` query values selecting every record whose day is within
/// [firstDay] .. [lastDay] inclusive (y/m/d of the arguments only).
({String from, String to}) attendanceWindow(DateTime firstDay, DateTime lastDay) => (
      from: DateTime.utc(firstDay.year, firstDay.month, firstDay.day - 1, 12).toIso8601String(),
      to: DateTime.utc(lastDay.year, lastDay.month, lastDay.day, 12).toIso8601String(),
    );
