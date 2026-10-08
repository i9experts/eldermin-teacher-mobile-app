import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/student_leave_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/messaging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_messaging_repository.dart';

typedef Call = ({String method, String url, Object? data, Map<String, dynamic>? query});

/// Records every request; answers [body] (or throws the HTTP error [failStatus]).
class _Client extends BaseClient {
  Object? body;
  int? failStatus;
  String failMessage = 'boom';
  final calls = <Call>[];
  _Client([this.body]);

  Future<Response> _answer(String method, String url, Object? data, Map<String, dynamic>? q) async {
    calls.add((method: method, url: url, data: data, query: q));
    final ro = RequestOptions(path: url);
    final s = failStatus;
    if (s != null) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: s, data: {'statusCode': s, 'message': failMessage}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: body);
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _answer('GET', url, null, queryParameters);
  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _answer('POST', url, data, queryParameters);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) => _answer('PATCH', url, data, queryParameters);
}

const id = '64e000000000000000000a01';

void main() {
  group('request shapes (what is sent)', () {
    test('threads: status filter, messages, send {body}, read, close, guardians, create', () async {
      final c = _Client({'items': [], 'unreadCount': 0});
      final r = MessagingRepository(c);
      await r.fetchThreads(status: 'open');
      await r.fetchThreads();
      expect(c.calls[0].url, endsWith('/staff-portal/threads'));
      expect(c.calls[0].query, {'status': 'open'});
      expect(c.calls[1].query, isEmpty);

      c.body = {'thread': {'_id': id}, 'messages': []};
      await r.fetchThreadMessages(id);
      expect(c.calls.last.url, endsWith('/staff-portal/threads/$id/messages'));

      c.body = {'_id': 'm1', 'body': 'hi', 'senderRole': 'staff'};
      final m = await r.sendMessage(id, 'hi');
      expect(m.id, 'm1');
      expect(c.calls.last.method, 'POST');
      expect(c.calls.last.data, {'body': 'hi'});

      c.body = {'ok': true};
      await r.markThreadRead(id);
      expect(c.calls.last.method, 'POST');
      expect(c.calls.last.url, endsWith('/threads/$id/read'));

      c.body = {'_id': id, 'status': 'closed'};
      expect((await r.closeThread(id)).isClosed, isTrue);
      expect((c.calls.last.method, c.calls.last.url.endsWith('/threads/$id/close')), ('PATCH', true));

      c.body = [{'userId': id, 'name': 'Mrs A'}, {'name': 'no id'}];
      final g = await r.fetchGuardians('s1');
      expect(g.map((x) => x.userId), [id], reason: 'a row without userId cannot be messaged and is dropped');
      expect(c.calls.last.url, endsWith('/staff-portal/students/s1/guardians'));

      c.body = {'_id': 'new1', 'subject': 'S'};
      await r.createThread(const NewThreadRequest(studentId: 's1', guardianUserId: id, subject: ' S ', firstMessage: 'hello'));
      expect(c.calls.last.data, {'studentId': 's1', 'guardianUserId': id, 'subject': 'S', 'firstMessage': 'hello'});
      expect(c.calls.last.url, endsWith('/staff-portal/threads'));
    });

    test('notifications: limit/before/unread query, read, read-all', () async {
      final c = _Client({'items': [], 'nextCursor': null, 'unreadCount': 0});
      final r = MessagingRepository(c);
      await r.fetchNotifications();
      expect(c.calls.last.query, {'limit': 30});
      await r.fetchNotifications(before: '2026-10-05T07:00:00.000Z', limit: 10, unreadOnly: true);
      expect(c.calls.last.query, {'limit': 10, 'before': '2026-10-05T07:00:00.000Z', 'unread': 'true'});
      c.body = {'_id': 'n1', 'isRead': true};
      await r.markNotificationRead('n1');
      expect((c.calls.last.method, c.calls.last.url.endsWith('/notifications/n1/read')), ('POST', true));
      c.body = {'updated': 4};
      expect(await r.markAllNotificationsRead(), 4);
      expect(c.calls.last.url, endsWith('/notifications/read-all'));
    });

    test('student leaves: status + limit, review body only carries non-empty trimmed remarks', () async {
      final c = _Client({'items': []});
      final r = MessagingRepository(c);
      await r.fetchStudentLeaves(status: LeaveStatus.pending, limit: 100);
      expect(c.calls.last.query, {'status': 'pending', 'limit': 100});
      await r.fetchStudentLeaves();
      expect(c.calls.last.query, {'limit': 100});
      c.body = {'_id': id, 'status': 'approved'};
      await r.reviewStudentLeave(id, status: LeaveStatus.approved, remarks: '  ok  ');
      expect(c.calls.last.data, {'status': 'approved', 'remarks': 'ok'});
      expect((c.calls.last.method, c.calls.last.url.endsWith('/student-leaves/$id')), ('PATCH', true));
      await r.reviewStudentLeave(id, status: LeaveStatus.rejected, remarks: '   ');
      expect(c.calls.last.data, {'status': 'rejected'});
      await r.reviewStudentLeave(id, status: LeaveStatus.rejected);
      expect(c.calls.last.data, {'status': 'rejected'});
    });
  });

  group('errors: HTTP failure is an ApiException with its status, a wrong 2xx body is UnexpectedResponseShape', () {
    final calls = <String, Future<Object?> Function(MessagingRepository)>{
      'fetchThreads': (r) => r.fetchThreads(status: 'open'),
      'fetchThreadMessages': (r) => r.fetchThreadMessages(id),
      'sendMessage': (r) => r.sendMessage(id, 'x'),
      'markThreadRead': (r) => r.markThreadRead(id),
      'closeThread': (r) => r.closeThread(id),
      'fetchGuardians': (r) => r.fetchGuardians('s1'),
      'createThread': (r) => r.createThread(const NewThreadRequest(studentId: 's', guardianUserId: id, subject: 's', firstMessage: 'm')),
      'fetchNotifications': (r) => r.fetchNotifications(),
      'markNotificationRead': (r) => r.markNotificationRead('n'),
      'markAllNotificationsRead': (r) => r.markAllNotificationsRead(),
      'fetchStudentLeaves': (r) => r.fetchStudentLeaves(),
      'reviewStudentLeave': (r) => r.reviewStudentLeave(id, status: LeaveStatus.approved),
    };

    for (final status in [403, 404, 409, 500]) {
      test('HTTP $status keeps the status and the server text on every endpoint', () async {
        for (final e in calls.entries) {
          final c = _Client()
            ..failStatus = status
            ..failMessage = 'server says no';
          await expectLater(e.value(MessagingRepository(c)), throwsA(isA<ApiException>().having((x) => x.statusCode, 'status', status).having((x) => x.message, 'message', 'server says no').having((x) => x is UnexpectedResponseShape, 'shape', isFalse)), reason: e.key);
        }
      });
    }

    final badBodies = <String, Map<String, Object?>>{
      'fetchThreads': {'a Map without items': {'unreadCount': 1}, 'a List': [], 'a String': 'oops', 'null': null, 'items not a list': {'items': 'x'}, 'rows not objects': {'items': [1]}},
      'fetchThreadMessages': {'no thread': {'messages': []}, 'no messages': {'thread': {'_id': 'a'}}, 'a List': [], 'null': null, 'messages not a list': {'thread': {}, 'messages': {}}},
      'sendMessage': {'a List': [], 'a String': 's', 'null': null, 'no _id': {'body': 'x'}},
      'closeThread': {'a List': [], 'null': null},
      'fetchGuardians': {'a Map': {'a': 1}, 'a String': 's', 'null': null, 'rows not objects': [1]},
      'createThread': {'a List': [], 'null': null, 'no _id': {'subject': 's'}},
      'fetchNotifications': {'no items': {'unreadCount': 1}, 'a List': [], 'a String': 's', 'null': null, 'items not a list': {'items': 1}, 'rows not objects': {'items': ['x']}},
      'fetchStudentLeaves': {'no items': {'a': 1}, 'a List': [], 'a String': 's', 'null': null, 'rows not objects': {'items': [null]}},
      'reviewStudentLeave': {'a List': [], 'null': null, 'no _id': {'status': 'approved'}},
    };
    badBodies.forEach((name, cases) {
      test('$name: every wrong shape is UnexpectedResponseShape, never an empty result', () async {
        cases.forEach((shape, _) {});
        for (final entry in cases.entries) {
          final c = _Client(entry.value);
          await expectLater(calls[name]!(MessagingRepository(c)), throwsA(isA<UnexpectedResponseShape>()), reason: '$name / ${entry.key}');
        }
      });
    });

    test('valid empty answers are empty results, not errors', () async {
      expect((await MessagingRepository(_Client({'items': [], 'unreadCount': 0})).fetchThreads()).items, isEmpty);
      expect(await MessagingRepository(_Client([])).fetchGuardians('s'), isEmpty);
      expect((await MessagingRepository(_Client({'items': [], 'nextCursor': null, 'unreadCount': 0})).fetchNotifications()).items, isEmpty);
      expect(await MessagingRepository(_Client({'items': []})).fetchStudentLeaves(), isEmpty);
      expect((await MessagingRepository(_Client({'thread': {'_id': 'a'}, 'messages': []})).fetchThreadMessages('a')).messages, isEmpty);
    });
  });
}
