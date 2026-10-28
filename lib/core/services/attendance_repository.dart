import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/json_helpers.dart';
import '../models/classroom/attendance_models.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
import '../network/dio_exception_handler.dart';

/// One record of a bulk write. `date` is sent as noon UTC of [day] (see attendance_models.dart).
class AttendanceWrite {
  final String studentId;
  final String studentName;
  final String grade;
  final String section;
  final DateTime day;
  final AttendanceStatus status;

  /// Subject name, ONLY in a subject-wise school (what the web sends as `subject`, AttendanceTab.tsx:`...(isSubjectWise ? { subject: selectedSubject } : {})`).
  /// Null in a daily school: the key is then not sent at all, so the request is byte-for-byte what it was before.
  final String? subject;

  const AttendanceWrite({
    required this.studentId,
    required this.studentName,
    required this.grade,
    this.section = '',
    required this.day,
    required this.status,
    this.subject,
  });

  /// MarkAttendanceDto (student.dto.ts:261-275): studentId(MongoId) studentName grade section? date status subject? (subject: subject-wise schools only).
  /// schoolSlug / academicYear / markedBy are NOT sent: the server ignores them (stripped by the whitelist,
  /// main.ts:70-74; set from the token/headers in students.controller.ts:30-31).
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'grade': grade,
        if (section.isNotEmpty) 'section': section,
        'date': attendanceWireDate(day),
        'status': status.wire,
        if (subject != null && subject!.isNotEmpty) 'subject': subject,
      };
}

/// Answer of `GET /students/attendance/check-day`: is [day] a school day for the class's grade?
/// [unknown] = the check itself failed (never blocks marking; the server re-validates on save).
class SchoolDayStatus {
  final bool valid;
  final bool configured;
  final String? reason;
  final bool unknown;
  const SchoolDayStatus({required this.valid, this.configured = false, this.reason}) : unknown = false;
  const SchoolDayStatus.unknown()
      : valid = true,
        configured = false,
        reason = null,
        unknown = true;

  /// Defensive: anything but an explicit `valid: false` counts as valid.
  factory SchoolDayStatus.fromJson(Map<String, dynamic> m) {
    final reason = readString(m['reason'])?.trim();
    return SchoolDayStatus(
      valid: m['valid'] != false,
      configured: m['configured'] == true,
      reason: reason == null || reason.isEmpty ? null : reason,
    );
  }
}

/// `GET /teaching/attendance-settings` answered 403: the caller's custom role has no `attendance-settings` grant (the backend requires
/// `@RequireModuleAccess('teaching', 'attendance-settings', 'view')`), so the school's mode could NOT be read. Still an [ApiException] (status 403).
/// The controller continues in daily mode with a visible warning and a subject-evidence guard instead of guessing silently.
class AttendanceModeForbidden extends ApiException {
  AttendanceModeForbidden(super.message) : super(statusCode: 403);
}

/// Student attendance calls (class teachers).
class AttendanceRepository {
  final BaseClient _client;
  AttendanceRepository([BaseClient? client]) : _client = client ?? BaseClient();

  static const int pageSize = 1000; // AttendanceQueryDto limit max 1000 (student.dto.ts:30)
  static const int maxPages = 6;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// Records of the class for the days [firstDay]..[lastDay] (inclusive, y/m/d only):
  /// `GET /students/attendance/list?grade&section&from&to&limit&page` (students.controller.ts:451-457 ->
  /// students.service.ts:1825-1852). Uses `from`/`to`, NEVER `date` (stripped by the DTO whitelist: the web's
  /// `date=` returns the latest 20 records of any day). `grade`/`section` are the class-teacher class strings:
  /// for a class teacher the server forces them to the token's own strings anyway (scope.util.ts:163-180).
  /// [subject] narrows the list to one subject (subject-wise schools; without it every subject's record of the day is returned).
  /// Pages through `meta.pages` (up to [maxPages] x 1000 rows).
  Future<List<AttendanceRecord>> fetchRange({
    required String grade,
    String? section,
    required DateTime firstDay,
    required DateTime lastDay,
    String? subject,
  }) =>
      _guard(() async {
        final w = attendanceWindow(firstDay, lastDay);
        final out = <AttendanceRecord>[];
        for (var page = 1; page <= maxPages; page++) {
          final res = await _client.get(ApiConstants.attendanceList, queryParameters: {
            'grade': grade,
            if (section != null && section.isNotEmpty) 'section': section,
            if (subject != null && subject.isNotEmpty) 'subject': subject, // AttendanceQueryDto.subject (subject-wise schools only)
            'from': w.from,
            'to': w.to,
            'limit': pageSize,
            'page': page,
          });
          final body = expectMap(res.data, what: 'attendance');
          expectKeyRows(body, 'data', what: 'attendance');
          final p = AttendancePage.fromJson(body);
          out.addAll(p.records);
          if (page >= p.pages) break;
        }
        return out;
      });

  /// `GET /students/attendance/check-day?date&grade` (students.controller.ts:529-538): whether [day] is a school day for [grade]
  /// (working days + holidays of the academic year; not configured = valid). `date` is noon UTC of [day] ([attendanceWireDate]).
  /// Never throws: 404 (older server) = valid; every other failure = [SchoolDayStatus.unknown] (the save-time 400 still protects).
  Future<SchoolDayStatus> checkDay({required DateTime day, String? grade}) async {
    try {
      final res = await _guard(() => _client.get(ApiConstants.attendanceCheckDay, queryParameters: {
            'date': attendanceWireDate(day),
            if (grade != null && grade.isNotEmpty) 'grade': grade,
          }));
      return SchoolDayStatus.fromJson(expectMap(res.data, what: 'the school-day check'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const SchoolDayStatus(valid: true);
      return const SchoolDayStatus.unknown();
    } catch (_) {
      return const SchoolDayStatus.unknown();
    }
  }

  /// `POST /students/attendance/bulk` { records: [...] } -> HTTP 201 with a Mongo BulkWriteResult
  /// (students.controller.ts:481-493 -> students.service.ts:1810-1823). The response BODY IS IGNORED
  /// (its JSON shape is UNVERIFIED, U5): success = a 2xx status. Upserts per (student, day), so
  /// re-sending a day edits it. `x-academic-year` is the only way to set the record's academic year
  /// (students.controller.ts:30-31; the JWT has none and the default is the literal '2025-26').
  Future<void> submit(List<AttendanceWrite> records, {String? academicYear}) => _guard(() async {
        await _client.post(
          ApiConstants.attendanceBulk,
          data: {'records': [for (final r in records) r.toJson()]},
          headers: {if (academicYear != null && academicYear.isNotEmpty) 'x-academic-year': academicYear},
        );
      });

  /// `GET /teaching/attendance-settings` -> `{ mode }`. A 404/501 (a server that does not have the feature yet) means
  /// `daily`; every other failure is rethrown so the screen never GUESSES the mode (a wrong guess would save a
  /// whole-day mark in a subject-wise school). A 403 (custom role without the `attendance-settings` grant) is the one distinct,
  /// typed outcome: [AttendanceModeForbidden].
  Future<AttendanceMode> fetchMode() async {
    try {
      final res = await _guard(() => _client.get(ApiConstants.attendanceSettings));
      return AttendanceMode.fromWire(expectMap(res.data, what: 'the attendance mode')['mode']);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) return AttendanceMode.daily;
      if (e.statusCode == 403) throw AttendanceModeForbidden(e.message);
      rethrow;
    }
  }

  /// `GET /academics/subjects` (the same call the web's subject picker makes: active subjects of the school, no
  /// `assignedOnly`) -> subject NAMES, in server order (name ascending). Tolerates a bare array or `{data:[...]}`.
  Future<List<String>> fetchSubjectNames() => _guard(() async {
        final res = await _client.get(ApiConstants.subjects);
        final out = <String>[];
        for (final m in expectRows(res.data, what: 'subjects')) {
          final n = readString(m['name'])?.trim();
          if (n != null && n.isNotEmpty && !out.contains(n)) out.add(n);
        }
        return out;
      });
}
