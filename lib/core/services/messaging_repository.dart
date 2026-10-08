import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/home/messaging.dart';
import '../models/json_helpers.dart';
import '../models/messaging/chat_models.dart';
import '../models/messaging/notification_models.dart';
import '../models/messaging/student_leave_models.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7a network calls: parent messaging, the notifications inbox and student-leave review. Every endpoint is on eldermin-backend
/// `feat/staff-portal` (src/staff-portal/staff-portal.controller.ts, SPC) and NOT deployed to production yet: a 404/501 means "not available
/// on this server yet". Every method throws [ApiException] (offline / 403 / 404 / 409 / 5xx mapped by [DioExceptionHandler]); a body of the
/// wrong shape is an [UnexpectedResponseShape] (never an empty list).
class MessagingRepository {
  final BaseClient _client;
  MessagingRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  // ── Threads ────────────────────────────────────────────────────
  /// `GET /staff-portal/threads?status=open|closed` (SPC:49-50 -> SPS:217-223): `{ items, unreadCount }`, sorted lastMessageAt desc, at most
  /// 100 rows. [status] null = all.
  Future<ThreadsResult> fetchThreads({String? status}) => _guard(() async {
        final res = await _client.get(ApiConstants.threads, queryParameters: {if (status != null) 'status': status});
        final body = expectMap(res.data, what: 'messages');
        expectKeyRows(body, 'items', what: 'messages');
        return ThreadsResult.fromJson(body);
      });

  /// `GET /staff-portal/threads/:id/messages` (SPC:56-57 -> SPS:233-237): `{ thread, messages }`, messages oldest first.
  Future<ThreadMessages> fetchThreadMessages(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.threadMessages(id));
        final body = expectMap(res.data, what: 'this conversation');
        final thread = body['thread'];
        if (thread is! Map) throw UnexpectedResponseShape('this conversation', '"thread" is not an object');
        final rows = expectKeyRows(body, 'messages', what: 'this conversation');
        return ThreadMessages(
          thread: MessageThread.fromJson(asJsonMap(thread)),
          messages: rows.map(ChatMessage.fromJson).toList(),
        );
      });

  /// `POST /staff-portal/threads/:id/messages {body}` (SPC:59-63 -> SPS:239-258, 201): the created message. 409 'This conversation is
  /// closed.' (SPS:241), 400 validation (SendThreadMessageDto: 1..4000 chars, staff-portal.dto.ts:3-5).
  Future<ChatMessage> sendMessage(String id, String body) => _guard(() async {
        final res = await _client.post(ApiConstants.threadMessages(id), data: {'body': body});
        final m = ChatMessage.fromJson(expectMap(res.data, what: 'the sent message'));
        if (m.id.isEmpty) throw UnexpectedResponseShape('the sent message', '_id missing');
        return m;
      });

  /// `POST /staff-portal/threads/:id/read` (SPC:65-67 -> SPS:260-265, 200 `{ok:true}`).
  Future<void> markThreadRead(String id) => _guard(() async {
        await _client.post(ApiConstants.threadRead(id));
      });

  /// `PATCH /staff-portal/threads/:id/close` (SPC:69-70 -> SPS:267-272): the closed thread document.
  Future<MessageThread> closeThread(String id) => _guard(() async {
        final res = await _client.patch(ApiConstants.threadClose(id));
        return MessageThread.fromJson(expectMap(res.data, what: 'this conversation'));
      });

  /// `GET /staff-portal/students/:studentId/guardians` (SPC:72-75 -> SPS:274-284): bare array `[ { userId, name } ]`. 403 'You do not
  /// teach this student.' (SPS:292) / 404 'Student not found' (SPS:288-290).
  Future<List<GuardianName>> fetchGuardians(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.studentGuardians(studentId));
        return expectRows(res.data, what: 'guardians').map(GuardianName.fromJson).where((g) => g.userId.isNotEmpty).toList();
      });

  /// `POST /staff-portal/threads` (SPC:52-54 -> SPS:298-323, 201): the new thread document.
  Future<MessageThread> createThread(NewThreadRequest r) => _guard(() async {
        final res = await _client.post(ApiConstants.threads, data: r.toJson());
        final t = MessageThread.fromJson(expectMap(res.data, what: 'the new conversation'));
        if (t.id.isEmpty) throw UnexpectedResponseShape('the new conversation', '_id missing');
        return t;
      });

  // ── Notifications ──────────────────────────────────────────────
  /// `GET /staff-portal/notifications?limit&before&unread=true` (SPC:34-35 -> SPS:172-189).
  Future<NotificationsPage> fetchNotifications({String? before, int limit = 30, bool unreadOnly = false}) => _guard(() async {
        final res = await _client.get(ApiConstants.notifications, queryParameters: {
          'limit': limit,
          if (before != null) 'before': before,
          if (unreadOnly) 'unread': 'true',
        });
        final body = expectMap(res.data, what: 'notifications');
        return NotificationsPage.fromJson(body, expectKeyRows(body, 'items', what: 'notifications'));
      });

  /// `POST /staff-portal/notifications/:id/read` (SPC:44-46 -> SPS:197-205). 404 'Notification not found'.
  Future<void> markNotificationRead(String id) => _guard(() async {
        await _client.post(ApiConstants.notificationRead(id));
      });

  /// `POST /staff-portal/notifications/read-all` (SPC:40-42 -> SPS:207-213): `{ updated }`.
  Future<int> markAllNotificationsRead() => _guard(() async {
        final res = await _client.post(ApiConstants.notificationsReadAll);
        return readInt(asJsonMap(res.data)['updated']) ?? 0;
      });

  // ── Student leave review (class teacher) ───────────────────────
  /// `GET /staff-portal/student-leaves?status=&limit=` (SPC:78-79 -> SPS:327-341): `{ items }`, newest first, limit 1..200 (default 50).
  /// 403 'Only class teachers can review student leave requests.' (SPS:105).
  Future<List<StudentLeaveRequest>> fetchStudentLeaves({LeaveStatus? status, int limit = 100}) => _guard(() async {
        final res = await _client.get(ApiConstants.studentLeaves, queryParameters: {
          if (status != null) 'status': status.wire,
          'limit': limit,
        });
        final body = expectMap(res.data, what: 'leave requests');
        return expectKeyRows(body, 'items', what: 'leave requests').map(StudentLeaveRequest.fromJson).where((l) => l.id.isNotEmpty).toList();
      });

  /// `PATCH /staff-portal/student-leaves/:id {status, remarks?}` (SPC:81-84 -> SPS:343-367): the updated leave document.
  /// 409 'This request was already <status>.' (SPS:354), 403 'This student is not in your class.' (SPS:352), 404 'Leave request not found'.
  Future<StudentLeaveRequest> reviewStudentLeave(String id, {required LeaveStatus status, String? remarks}) => _guard(() async {
        final trimmed = remarks?.trim() ?? '';
        final res = await _client.patch(ApiConstants.studentLeave(id), data: {'status': status.wire, if (trimmed.isNotEmpty) 'remarks': trimmed});
        final l = StudentLeaveRequest.fromJson(expectMap(res.data, what: 'the leave request'));
        if (l.id.isEmpty) throw UnexpectedResponseShape('the leave request', '_id missing');
        return l;
      });
}
