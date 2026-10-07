import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/home/class_snapshot.dart';
import '../models/home/messaging.dart';
import '../models/home/pending_grading.dart';
import '../models/home/teaching.dart';
import '../models/home/timetable.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
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

  /// Bare JSON arrays are the norm; tolerate a `{ data: [...] }` wrapper. Anything else is [UnexpectedResponseShape] (never an empty list).
  List<Map<String, dynamic>> _list(Object? body, String what) => expectRows(body, what: what);

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  // ── Timetable ─────────────────────────────────────────────────
  /// `GET /teaching/timetable/teacher/:staffId` -> whole class documents.
  Future<List<TimetableDoc>> fetchTeacherTimetable(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.timetableForTeacher(staffId));
        return _list(res.data, 'the timetable').map(TimetableDoc.fromJson).toList();
      });

  /// `GET /staff-portal/timetable?date=YYYY-MM-DD` (when [from] and [to] are the same calendar day)
  /// or `?from=&to=` (max 14 days, inclusive). Own slots only, resolved server-side by Staff._id,
  /// including split-group-only teachers (staff-teaching.service.ts:153-225). Dates are CALENDAR
  /// dates (the device-local date is sent; there is no server-side "today"). Throws
  /// [ApiException] 404 on servers where the endpoint is not deployed. Generic on purpose: the
  /// Phase 5 Timetable module reuses it.
  Future<MyTimetable> getMyTimetable(DateTime from, DateTime to) => _guard(() async {
        final f = _ymd(from), t = _ymd(to);
        final res = await _client.get(ApiConstants.myTimetable,
            queryParameters: f == t ? {'date': f} : {'from': f, 'to': t});
        final body = expectMap(res.data, what: 'the timetable');
        expectKeyRows(body, 'days', what: 'the timetable');
        return MyTimetable.fromJson(body);
      });

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Class-teacher card ────────────────────────────────────────
  /// `GET /students/class-roster-diagnostic?grade=&section=`.
  Future<RosterCount> fetchRoster({required String grade, String? section}) => _guard(() async {
        final res = await _client.get(ApiConstants.classRosterDiagnostic,
            queryParameters: {'grade': grade, if (section != null && section.isNotEmpty) 'section': section});
        return RosterCount.fromJson(expectMap(res.data, what: 'the class roster'));
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
        return attendanceTotalFromJson(expectMap(res.data, what: 'attendance'));
      });

  // ── Homework ──────────────────────────────────────────────────
  /// `GET /teaching/assignments?teacherId=<staffId>` (sorted dueDate desc, unbounded).
  Future<List<HomeworkAssignment>> fetchAssignments(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignments, queryParameters: {'teacherId': staffId});
        return _list(res.data, 'homework').map(HomeworkAssignment.fromJson).toList();
      });

  /// `GET /teaching/assignments/:id/submissions` -> `submissions[]`.
  Future<List<HomeworkSubmission>> fetchSubmissions(String assignmentId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignmentSubmissions(assignmentId));
        return expectKeyRows(expectMap(res.data, what: 'submissions'), 'submissions', what: 'submissions').map(HomeworkSubmission.fromJson).toList();
      });

  /// `GET /staff-portal/homework/pending-grading?limit=` -> ungraded counts per assignment in one
  /// aggregation (staff-teaching.service.ts:58-117). 404 when not deployed (callers fall back).
  Future<PendingGrading> getPendingGrading({int? limit}) => _guard(() async {
        final res = await _client.get(ApiConstants.pendingGrading,
            queryParameters: {if (limit != null) 'limit': limit});
        final body = expectMap(res.data, what: 'pending grading');
        expectKeyRows(body, 'items', what: 'pending grading');
        return PendingGrading.fromJson(body);
      });

  // ── Lesson plans ──────────────────────────────────────────────
  /// `GET /teaching/lesson-plans?teacherId=<staffId>&status=<status>` (hard limit 100).
  Future<List<LessonPlan>> fetchLessonPlans(String staffId, String status) => _guard(() async {
        final res = await _client
            .get(ApiConstants.lessonPlans, queryParameters: {'teacherId': staffId, 'status': status});
        return _list(res.data, 'lesson plans').map(LessonPlan.fromJson).toList();
      });

  // ── PTM ───────────────────────────────────────────────────────
  /// `GET /teaching/ptm/upcoming/mine?teacherId=<staffId>`.
  Future<List<PtmMeeting>> fetchUpcomingPtms(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.ptmUpcomingMine, queryParameters: {'teacherId': staffId});
        return _list(res.data, 'parent-teacher meetings').map(PtmMeeting.fromJson).toList();
      });

  /// `GET /teaching/ptm?teacherId=<staffId>&from=<ISO>&to=<ISO>` (ptm.controller.ts:18-21 ->
  /// ptm.service.ts:91-104): any status, scheduledDate in [from, to] (inclusive, `new Date(x)`),
  /// sorted scheduledDate desc, hard limit 200, campus-scoped. Used for TODAY's meetings, which
  /// `ptm/upcoming/mine` drops after UTC midnight (ptm.service.ts:181).
  Future<List<PtmMeeting>> fetchPtmsInRange(String staffId, {required DateTime from, required DateTime to}) =>
      _guard(() async {
        final res = await _client.get(ApiConstants.ptm,
            queryParameters: {'teacherId': staffId, 'from': _iso(from), 'to': _iso(to)});
        return _list(res.data, 'parent-teacher meetings').map(PtmMeeting.fromJson).toList();
      });

  // ── Substitutions ─────────────────────────────────────────────
  /// `GET /teaching/fixtures?teacherId=<staffId>&from=&to=` (original OR substitute).
  Future<List<Substitution>> fetchSubstitutions(String staffId, {required DateTime from, required DateTime to}) =>
      _guard(() async {
        final res = await _client.get(ApiConstants.fixtures,
            queryParameters: {'teacherId': staffId, 'from': _iso(from), 'to': _iso(to)});
        return _list(res.data, 'substitutions').map(Substitution.fromJson).toList();
      });

  // ── Messaging / notifications (NOT deployed to production yet) ──
  /// `GET /staff-portal/threads?status=open`.
  Future<ThreadsResult> fetchOpenThreads() => _guard(() async {
        final res = await _client.get(ApiConstants.threads, queryParameters: {'status': 'open'});
        final body = expectMap(res.data, what: 'messages');
        expectKeyRows(body, 'items', what: 'messages');
        return ThreadsResult.fromJson(body);
      });

  /// `GET /staff-portal/notifications/unread-count` -> `{ unreadCount }`.
  Future<int> fetchNotificationUnreadCount() => _guard(() async {
        final res = await _client.get(ApiConstants.notificationsUnreadCount);
        final n = readInt(expectMap(res.data, what: 'notifications')['unreadCount']);
        if (n == null) throw UnexpectedResponseShape('notifications', 'unreadCount missing');
        return n;
      });
}
