import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/classroom/attendance_models.dart';
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

  const AttendanceWrite({
    required this.studentId,
    required this.studentName,
    required this.grade,
    this.section = '',
    required this.day,
    required this.status,
  });

  /// MarkAttendanceDto (student.dto.ts:261-275): studentId(MongoId) studentName grade section? date status.
  /// schoolSlug / academicYear / markedBy are NOT sent: the server ignores them (stripped by the whitelist,
  /// main.ts:70-74; set from the token/headers in students.controller.ts:30-31).
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'grade': grade,
        if (section.isNotEmpty) 'section': section,
        'date': attendanceWireDate(day),
        'status': status.wire,
      };
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
  /// Pages through `meta.pages` (up to [maxPages] x 1000 rows).
  Future<List<AttendanceRecord>> fetchRange({
    required String grade,
    String? section,
    required DateTime firstDay,
    required DateTime lastDay,
  }) =>
      _guard(() async {
        final w = attendanceWindow(firstDay, lastDay);
        final out = <AttendanceRecord>[];
        for (var page = 1; page <= maxPages; page++) {
          final res = await _client.get(ApiConstants.attendanceList, queryParameters: {
            'grade': grade,
            if (section != null && section.isNotEmpty) 'section': section,
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
}
