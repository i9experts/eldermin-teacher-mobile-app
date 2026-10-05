import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/home/class_snapshot.dart';
import '../models/home/messaging.dart';
import '../models/home/teaching.dart';
import '../models/home/timetable.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// Read-only network calls behind the Home dashboard, grouped per endpoint
/// family. Every method throws [ApiException] (offline / 403 / 404 / 5xx
/// mapped by [DioExceptionHandler]; a 401 already triggers the global
/// logout in the network layer).
///
/// The server does NOT enforce ownership on `/teaching/*` and `/students/*`
/// reads (shapes doc, section 10), so every method that takes a teacher id
/// takes the Staff._id from `GET /staff-portal/me`, and callers also filter
/// client-side.
class HomeRepository {
  final BaseClient _client;
  HomeRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// Bare JSON arrays are the norm; tolerate a `{ data: [...] }` wrapper.
  List<Map<String, dynamic>> _list(Object? body) {
    if (body is Map && body['data'] is List) return asJsonMapList(body['data']);
    return asJsonMapList(body);
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  // ── Timetable ─────────────────────────────────────────────────
  /// `GET /teaching/timetable/teacher/:staffId` -> whole class documents.
  Future<List<TimetableDoc>> fetchTeacherTimetable(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.timetableForTeacher(staffId));
        return _list(res.data).map(TimetableDoc.fromJson).toList();
      });

  // ── Class-teacher card ────────────────────────────────────────
  /// `GET /students/class-roster-diagnostic?grade=&section=`.
  Future<RosterCount> fetchRoster({required String grade, String? section}) => _guard(() async {
        final res = await _client.get(ApiConstants.classRosterDiagnostic,
            queryParameters: {'grade': grade, if (section != null && section.isNotEmpty) 'section': section});
        return RosterCount.fromJson(asJsonMap(res.data));
      });

  /// `GET /students/attendance/list?grade&section&from&to&limit=1` -> `meta.total`.
  Future<int> fetchAttendanceCount({
    required String grade,
    String? section,
    required DateTime from,
    required DateTime to,
  }) =>
      _guard(() async {
        final res = await _client.get(ApiConstants.attendanceList, queryParameters: {
          'grade': grade,
          if (section != null && section.isNotEmpty) 'section': section,
          'from': _iso(from),
          'to': _iso(to),
          'limit': 1,
        });
        return attendanceTotalFromJson(asJsonMap(res.data));
      });

  // ── Homework ──────────────────────────────────────────────────
  /// `GET /teaching/assignments?teacherId=<staffId>` (sorted dueDate desc, unbounded).
  Future<List<HomeworkAssignment>> fetchAssignments(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignments, queryParameters: {'teacherId': staffId});
        return _list(res.data).map(HomeworkAssignment.fromJson).toList();
      });

  /// `GET /teaching/assignments/:id/submissions` -> `submissions[]`.
  Future<List<HomeworkSubmission>> fetchSubmissions(String assignmentId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignmentSubmissions(assignmentId));
        return asJsonMapList(asJsonMap(res.data)['submissions']).map(HomeworkSubmission.fromJson).toList();
      });

  // ── Lesson plans ──────────────────────────────────────────────
  /// `GET /teaching/lesson-plans?teacherId=<staffId>&status=<status>` (hard limit 100).
  Future<List<LessonPlan>> fetchLessonPlans(String staffId, String status) => _guard(() async {
        final res = await _client
            .get(ApiConstants.lessonPlans, queryParameters: {'teacherId': staffId, 'status': status});
        return _list(res.data).map(LessonPlan.fromJson).toList();
      });

  // ── PTM ───────────────────────────────────────────────────────
  /// `GET /teaching/ptm/upcoming/mine?teacherId=<staffId>`.
  Future<List<PtmMeeting>> fetchUpcomingPtms(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.ptmUpcomingMine, queryParameters: {'teacherId': staffId});
        return _list(res.data).map(PtmMeeting.fromJson).toList();
      });

  // ── Substitutions ─────────────────────────────────────────────
  /// `GET /teaching/fixtures?teacherId=<staffId>&from=&to=` (original OR substitute).
  Future<List<Substitution>> fetchSubstitutions(String staffId, {required DateTime from, required DateTime to}) =>
      _guard(() async {
        final res = await _client.get(ApiConstants.fixtures,
            queryParameters: {'teacherId': staffId, 'from': _iso(from), 'to': _iso(to)});
        return _list(res.data).map(Substitution.fromJson).toList();
      });

  // ── Messaging / notifications (NOT deployed to production yet) ──
  /// `GET /staff-portal/threads?status=open`.
  Future<ThreadsResult> fetchOpenThreads() => _guard(() async {
        final res = await _client.get(ApiConstants.threads, queryParameters: {'status': 'open'});
        return ThreadsResult.fromJson(asJsonMap(res.data));
      });

  /// `GET /staff-portal/notifications/unread-count` -> `{ unreadCount }`.
  Future<int> fetchNotificationUnreadCount() => _guard(() async {
        final res = await _client.get(ApiConstants.notificationsUnreadCount);
        return readInt(asJsonMap(res.data)['unreadCount']) ?? 0;
      });
}
