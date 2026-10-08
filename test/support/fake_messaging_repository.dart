import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/notification_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/student_leave_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/messaging_repository.dart';

dynamic fx7(String n) => jsonDecode(File('test/fixtures/phase7a/$n.json').readAsStringSync());

Never fail7(int? status, [String message = 'error']) => throw ApiException(message, statusCode: status);

MessageThread thread(String id,
        {String guardian = 'Mrs Malik',
        String student = 'Zara Malik',
        String subject = 'Homework',
        String preview = 'Hello',
        bool unread = false,
        String status = 'open',
        DateTime? at}) =>
    MessageThread.fromJson({
      '_id': id,
      'subject': subject,
      'studentId': 'st1',
      'studentName': student,
      'guardianName': guardian,
      'lastMessagePreview': preview,
      'lastMessageAt': (at ?? DateTime.utc(2026, 10, 5, 8)).toIso8601String(),
      'staffHasUnread': unread,
      'status': status,
    });

ChatMessage serverMsg(String id, String body, {bool mine = false, DateTime? at}) => ChatMessage.fromJson({
      '_id': id,
      'threadId': 't1',
      'senderRole': mine ? 'staff' : 'guardian',
      'senderName': mine ? 'Tess Teacher' : 'Mrs Malik',
      'body': body,
      'createdAt': (at ?? DateTime.utc(2026, 10, 5, 8)).toIso8601String(),
    });

AppNotification notif(String id,
        {String type = 'message', String title = 'New message', String body = 'Hi', String entity = '', bool read = false, DateTime? at}) =>
    AppNotification.fromJson({
      '_id': id,
      'type': type,
      'title': title,
      'body': body,
      if (entity.isNotEmpty) 'relatedEntityId': entity,
      'isRead': read,
      'createdAt': (at ?? DateTime.utc(2026, 10, 5, 8)).toIso8601String(),
    });

StudentLeaveRequest leaveReq(String id,
        {String status = 'pending', String student = 'Zara Malik', String? by, String? note, DateTime? decided}) =>
    StudentLeaveRequest.fromJson({
      '_id': id,
      'studentId': 'st1',
      'studentName': student,
      'fromDate': '2026-10-09T00:00:00.000Z',
      'toDate': '2026-10-10T00:00:00.000Z',
      'reason': 'Fever',
      'leaveType': 'sick',
      'requestedByName': 'Mrs Malik',
      'status': status,
      if (by != null) 'approverName': by,
      if (note != null) 'approverNote': note,
      if (decided != null) 'approvedAt': decided.toIso8601String(),
      'createdAt': '2026-10-07T05:00:00.000Z',
    });

/// Scriptable [MessagingRepository]: one handler per endpoint, every call recorded in [calls].
class FakeMessagingRepository extends MessagingRepository {
  Future<ThreadsResult> Function(String? status) threads = (_) async => const ThreadsResult();
  Future<ThreadMessages> Function(String id) messages = (id) async => ThreadMessages(thread: thread(id));
  Future<ChatMessage> Function(String id, String body) send = (id, body) async => serverMsg('m-new', body, mine: true);
  Future<void> Function(String id) read = (_) async {};
  Future<MessageThread> Function(String id) close = (id) async => thread(id, status: 'closed');
  Future<List<GuardianName>> Function(String studentId) guardians = (_) async => const [];
  Future<MessageThread> Function(NewThreadRequest r) create = (r) async => thread('new1', subject: r.subject);
  Future<NotificationsPage> Function(String? before, int limit, bool unreadOnly) notifications = (_, __, ___) async => const NotificationsPage();
  Future<void> Function(String id) markNotification = (_) async {};
  Future<int> Function() markAll = () async => 0;
  Future<List<StudentLeaveRequest>> Function(LeaveStatus? status, int limit) leaves = (_, __) async => [];
  Future<StudentLeaveRequest> Function(String id, LeaveStatus status, String? remarks) review = (id, s, r) async => leaveReq(id, status: s.wire);

  final calls = <String>[];
  final sentBodies = <String>[];

  @override
  Future<ThreadsResult> fetchThreads({String? status}) {
    calls.add('threads:${status ?? 'all'}');
    return threads(status);
  }

  @override
  Future<ThreadMessages> fetchThreadMessages(String id) {
    calls.add('messages:$id');
    return messages(id);
  }

  @override
  Future<ChatMessage> sendMessage(String id, String body) {
    calls.add('send:$id');
    sentBodies.add(body);
    return send(id, body);
  }

  @override
  Future<void> markThreadRead(String id) {
    calls.add('read:$id');
    return read(id);
  }

  @override
  Future<MessageThread> closeThread(String id) {
    calls.add('close:$id');
    return close(id);
  }

  @override
  Future<List<GuardianName>> fetchGuardians(String studentId) {
    calls.add('guardians:$studentId');
    return guardians(studentId);
  }

  @override
  Future<MessageThread> createThread(NewThreadRequest r) {
    calls.add('create:${r.studentId}:${r.guardianUserId}');
    return create(r);
  }

  @override
  Future<NotificationsPage> fetchNotifications({String? before, int limit = 30, bool unreadOnly = false}) {
    calls.add('notifs:${before ?? '-'}:$limit:${unreadOnly ? 'unread' : 'all'}');
    return notifications(before, limit, unreadOnly);
  }

  @override
  Future<void> markNotificationRead(String id) {
    calls.add('nread:$id');
    return markNotification(id);
  }

  @override
  Future<int> markAllNotificationsRead() {
    calls.add('nreadall');
    return markAll();
  }

  @override
  Future<List<StudentLeaveRequest>> fetchStudentLeaves({LeaveStatus? status, int limit = 100}) {
    calls.add('leaves:${status?.wire ?? 'all'}');
    return leaves(status, limit);
  }

  @override
  Future<StudentLeaveRequest> reviewStudentLeave(String id, {required LeaveStatus status, String? remarks}) {
    calls.add('review:$id:${status.wire}');
    return review(id, status, remarks);
  }
}

/// Manual replacement for [Timer.periodic]: tests call [fire]; nothing waits on the wall clock and no real timer is ever created.
class FakePoller {
  final created = <Duration>[];
  int cancelled = 0;
  void Function()? _tick;
  bool active = false;

  Timer create(Duration d, void Function() tick) {
    created.add(d);
    _tick = tick;
    active = true;
    return _FakeTimer(this);
  }

  /// One poll tick, only while the timer is running (a cancelled timer never fires).
  void fire() {
    if (active) _tick?.call();
  }
}

class _FakeTimer implements Timer {
  final FakePoller _p;
  _FakeTimer(this._p);
  @override
  void cancel() {
    if (_p.active) _p.cancelled++;
    _p.active = false;
  }

  @override
  bool get isActive => _p.active;
  @override
  int get tick => 0;
}
