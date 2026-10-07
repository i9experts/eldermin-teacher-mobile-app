import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/classroom/attendance_models.dart';
import '../models/classroom/student_360.dart';
import '../models/classroom/student_models.dart';
import '../models/json_helpers.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
import '../network/dio_exception_handler.dart';
import '../utils/roster_scope.dart';

/// Read-only student calls: class rosters, Student 360, attendance summary.
///
/// EVERY payload goes through the whitelist models ([StudentSummary],
/// [Student360]) - fee, contact and finance fields in the raw responses are
/// never parsed. The server only scopes these reads by campus (hardening
/// backlog item 6), so [fetchClassRoster] also filters client-side.
class StudentsRepository {
  final BaseClient _client;
  StudentsRepository([BaseClient? client]) : _client = client ?? BaseClient();

  /// Hard cap on pages per roster (200 rows each): a class is tens of students; this only
  /// bounds a runaway server.
  static const int rosterPageSize = 200;
  static const int maxRosterPages = 5;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /students/filters/grades-sections` (students.controller.ts:61-66): school-wide RAW strings.
  Future<GradesSections> fetchGradesSections() => _guard(() async {
        final res = await _client.get(ApiConstants.studentGradesSections);
        final body = expectMap(res.data, what: 'the class list');
        if (body['grades'] is! List) throw UnexpectedResponseShape('the class list', '"grades" is not a list');
        return GradesSections.fromJson(body);
      });

  /// Active students of [cls]:
  ///   `GET /students?grade=<raw variants>&section=<raw variants>&status=active&limit=200&page=n`
  /// (students.controller.ts:54-59 -> students.service.ts:515-623; repeated `grade`/`section` params are
  /// exact `$in` filters, :520-521, hence the raw variants from [queryVariants]). The result is then
  /// re-scoped client-side with the backend's tolerant matcher ([scopeRoster]).
  Future<List<StudentSummary>> fetchClassRoster(ClassRef cls, {GradesSections? known}) => _guard(() async {
        final v = queryVariants(cls, known);
        final all = <StudentSummary>[];
        for (var page = 1; page <= maxRosterPages; page++) {
          final res = await _client.get(ApiConstants.students, queryParameters: {
            'grade': v.grades,
            if (v.sections.isNotEmpty) 'section': v.sections,
            'status': 'active',
            'limit': rosterPageSize,
            'page': page,
          });
          final body = expectMap(res.data, what: 'students');
          all.addAll(expectKeyRows(body, 'data', what: 'students').map(StudentSummary.fromJson));
          final pages = readInt(asJsonMap(body['meta'])['pages']) ?? 1;
          if (page >= pages) break;
        }
        return scopeRoster(all, cls);
      });

  /// `GET /students/:id/360` -> [Student360] (whitelisted; `fees` etc. dropped).
  Future<Student360> fetchStudent360(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.student360(id));
        return Student360.fromJson(expectMap(res.data, what: 'this student'));
      });

  /// `GET /students/:id/attendance/summary?month=YYYY-MM` -> counts per status
  /// (students.controller.ts:459-468 -> students.service.ts:1854-1864; bare array of `{_id, count}`).
  Future<StatusCounts> fetchAttendanceSummary(String id, {required int year, required int month}) => _guard(() async {
        final res = await _client.get(ApiConstants.attendanceSummary(id),
            queryParameters: {'month': '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}'});
        if (res.data is! List && res.data is! Map) throw UnexpectedResponseShape('attendance', 'expected a list');
        return StatusCounts.fromSummary(res.data);
      });
}
