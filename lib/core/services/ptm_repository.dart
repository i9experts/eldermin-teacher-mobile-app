import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/json_helpers.dart';
import '../models/ptm/ptm_models.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7b: parent-teacher meetings (eldermin-backend `src/modules/teaching/ptm.controller.ts` = PC, `ptm.service.ts` = PS, branch
/// feat/staff-portal 265fcfa). Every method throws [ApiException]; a body of the wrong shape is an [UnexpectedResponseShape].
///
/// All answers go through the teacher projection on the server (PC:19-22 ... `projectForTeacher`): guardian phone and email are removed.
class PtmRepository {
  final BaseClient _client;
  PtmRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  ParentMeeting _one(Object? body, String what) {
    final m = ParentMeeting.fromJson(expectMap(body, what: what));
    if (m.id.isEmpty) throw UnexpectedResponseShape(what, '_id missing');
    return m;
  }

  /// `GET /teaching/ptm?teacherId=<staffId>&from&to&status` (PC:19-22 -> PS:124-137): bare array, sorted scheduledDate DESC, at most 200,
  /// `from`/`to` are `new Date(x)` bounds on scheduledDate (inclusive). [from]/[to] are sent as UTC ISO strings.
  Future<List<ParentMeeting>> fetchMeetings({required String staffId, DateTime? from, DateTime? to, String? status}) => _guard(() async {
        final res = await _client.get(ApiConstants.ptm, queryParameters: {
          'teacherId': staffId,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (status != null) 'status': status,
        });
        return expectRows(res.data, what: 'parent meetings').map(ParentMeeting.fromJson).where((m) => m.id.isNotEmpty).toList();
      });

  /// `GET /teaching/ptm/:id` (PC:37-40 -> PS:139-145): the meeting; 404 'Meeting not found'; a non-ObjectId id is a 400 from
  /// `assertValidObjectId` (UNVERIFIED text). The server does NOT check that it is mine.
  Future<ParentMeeting> fetchMeeting(String id) => _guard(() async => _one((await _client.get(ApiConstants.ptmById(id))).data, 'this meeting'));

  /// `GET /teaching/ptm/student/:studentId/history` (PC:32-35 -> PS:147-153): every meeting of the student (any teacher), newest first, no
  /// limit.
  Future<List<ParentMeeting>> fetchStudentHistory(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.ptmStudentHistory(studentId));
        return expectRows(res.data, what: 'earlier meetings').map(ParentMeeting.fromJson).where((m) => m.id.isNotEmpty).toList();
      });

  /// `POST /teaching/ptm` (PC:43-47 -> PS:69-122, 201): the created meeting (status `requested`). 403 'You can only create meetings for
  /// yourself' (teacher-identity.util.ts:76-79 via PS:71-73), 404 'Student not found' / 'Teacher not found' (PS:78-79).
  Future<ParentMeeting> create(PtmCreateRequest r) => _guard(() async => _one((await _client.post(ApiConstants.ptm, data: r.toJson())).data, 'the new meeting'));

  /// `PATCH /teaching/ptm/:id/confirm` (PC:49-53 -> PS:155-164): only from `requested`; else 404 'Meeting not found or not in a requested state'.
  Future<ParentMeeting> confirm(String id) => _guard(() async => _one((await _client.patch(ApiConstants.ptmConfirm(id))).data, 'this meeting'));

  /// `PATCH /teaching/ptm/:id/reschedule {scheduledDate, startTime?, endTime?}` (PC:55-59 -> PS:166-179): from requested|confirmed (else 404
  /// 'Meeting not found or already completed/cancelled'), the status becomes `requested`; omitted times CLEAR the stored times (PS:171), so the
  /// app always sends both. 403 'You can only modify your own meetings' (PS:30-37).
  Future<ParentMeeting> reschedule(String id, {required DateTime day, String? startTime, String? endTime}) => _guard(() async {
        final res = await _client.patch(ApiConstants.ptmReschedule(id), data: {
          'scheduledDate': wireDay(day),
          if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
          if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        });
        return _one(res.data, 'this meeting');
      });

  /// `PATCH /teaching/ptm/:id/outcome` (PC:61-65 -> PS:181-198): 403 'You can only modify your own meetings', 400 'Cannot record an outcome
  /// for a cancelled meeting' (PS:186).
  Future<ParentMeeting> recordOutcome(String id, PtmOutcomeRequest r) => _guard(() async => _one((await _client.patch(ApiConstants.ptmOutcome(id), data: r.toJson())).data, 'this meeting'));

  /// `PATCH /teaching/ptm/:id/action-items/:aid {status: pending|done}` (PC:67-74 -> PS:200-209): the whole meeting.
  Future<ParentMeeting> setActionItem(String id, String itemId, {required bool done}) =>
      _guard(() async => _one((await _client.patch(ApiConstants.ptmActionItem(id, itemId), data: {'status': done ? 'done' : 'pending'})).data, 'this meeting'));

  /// `PATCH /teaching/ptm/:id/cancel {reason}` (PC:76-79 -> PS:211-221): from ANY status; the guardians are notified by the server.
  Future<ParentMeeting> cancel(String id, String reason) => _guard(() async => _one((await _client.patch(ApiConstants.ptmCancel(id), data: {'reason': reason.trim()})).data, 'this meeting'));
}
