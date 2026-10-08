import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/notification_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/student_leave_models.dart';
import 'package:eldermin_teacher_app/core/utils/message_time.dart';
import 'package:eldermin_teacher_app/core/utils/notification_target.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_messaging_repository.dart';

const id = '64e000000000000000000a01';

void main() {
  group('models parse the exact stub shapes (which mirror the backend code)', () {
    test('threads fixture -> ThreadsResult', () {
      final r = ThreadsResult.fromJson(fx7('threads'));
      expect(r.items, hasLength(4));
      expect(r.items.first.guardianName, isNotEmpty);
      expect(r.items.first.studentName, isNotEmpty);
      expect(r.items.first.lastMessageAt, isNotNull);
      expect(r.items.where((t) => t.isClosed), hasLength(1));
      expect(r.serverUnreadCount, 3);
      expect(r.unreadCount, 2, reason: 'closed unread thread is not counted (owner rule)');
    });

    test('thread messages fixture -> thread + oldest-first messages with sender side', () {
      final j = fx7('thread_messages') as Map<String, dynamic>;
      final t = MessageThread.fromJson(Map<String, dynamic>.from(j['thread'] as Map));
      final msgs = (j['messages'] as List).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))).toList();
      expect(t.id, isNotEmpty);
      expect(msgs, isNotEmpty);
      expect(msgs.map((m) => m.createdAt!.millisecondsSinceEpoch).toList(), orderedEquals([...msgs.map((m) => m.createdAt!.millisecondsSinceEpoch)]..sort()));
      expect(msgs.any((m) => m.fromMe) && msgs.any((m) => !m.fromMe), isTrue);
      expect(msgs.first.id, isNotEmpty);
      expect(msgs.first.isLocal, isFalse);
    });

    test('guardians fixture: names only', () {
      final g = (fx7('guardians') as List).map((e) => GuardianName.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(g, isNotEmpty);
      expect(g.every((x) => x.userId.length == 24 && x.name.isNotEmpty), isTrue);
    });

    test('notifications pages: cursor, unread count, optional relatedEntityId', () {
      final j = Map<String, dynamic>.from(fx7('notifications_page1') as Map);
      final p = NotificationsPage.fromJson(j, (j['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
      expect(p.items, hasLength(10));
      expect(p.nextCursor, isNotNull);
      expect(p.unreadCount, 3);
      expect(p.items.where((n) => !n.isRead), hasLength(3));
      final last = Map<String, dynamic>.from(fx7('notifications_page2') as Map);
      expect(last['nextCursor'], isNotNull);
    });

    test('student leaves fixture', () {
      final rows = ((fx7('student_leaves') as Map)['items'] as List).map((e) => StudentLeaveRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(rows, hasLength(6));
      expect(rows.where((l) => l.isPending), hasLength(3));
      final decided = rows.firstWhere((l) => l.status == LeaveStatus.approved);
      expect(decided.approverName, isNotEmpty);
      expect(decided.decidedAt, isNotNull);
      expect(rows.first.firstDay, isNotNull);
      expect(rows.first.days, isNotNull);
    });
  });

  group('tolerant field parsing', () {
    test('missing and odd fields never throw', () {
      expect(MessageThread.fromJson({}).id, '');
      expect(ChatMessage.fromJson({}).body, '');
      expect(ChatMessage.fromJson({'senderRole': 'whatever'}).fromMe, isFalse);
      final n = AppNotification.fromJson({'_id': 'x', 'isRead': 'yes', 'type': null, 'createdAt': 'garbage'});
      expect(n.type, 'other');
      expect(n.isRead, isFalse);
      expect(n.createdAt, isNull);
      expect(StudentLeaveRequest.fromJson({'_id': 'l', 'status': 'weird'}).status, LeaveStatus.pending);
      expect(StudentLeaveRequest.fromJson({'_id': 'l', 'leaveType': 'x'}).typeLabel, 'Other');
      expect(MessageThread.fromJson({'status': 'weird'}).isClosed, isFalse);
    });

    test('leave dates are the calendar days that were written (UTC midnight), whatever the device timezone', () {
      final l = StudentLeaveRequest.fromJson({'_id': 'l', 'fromDate': '2026-10-09T00:00:00.000Z', 'toDate': '2026-10-11T00:00:00.000Z'});
      expect(l.firstDay, DateTime(2026, 10, 9));
      expect(l.lastDay, DateTime(2026, 10, 11));
      expect(l.days, 3);
      expect(StudentLeaveRequest.fromJson({'_id': 'l', 'fromDate': '2026-10-11T00:00:00.000Z', 'toDate': '2026-10-09T00:00:00.000Z'}).days, isNull);
    });

    test('ThreadsResult: a server that ignores status=open cannot inflate the open count', () {
      final r = ThreadsResult(items: [thread('a', unread: true), thread('b', unread: true, status: 'closed')]);
      expect(r.unreadCount, 1);
    });

    test('NewThreadRequest sends exactly the DTO fields, trimmed', () {
      expect(const NewThreadRequest(studentId: 's', guardianUserId: 'g', subject: ' a ', firstMessage: ' b ').toJson(),
          {'studentId': 's', 'guardianUserId': 'g', 'subject': 'a', 'firstMessage': 'b'});
    });
  });

  group('notification deep-link table', () {
    AppNotification n(String type, {String entity = id, String title = 'x'}) => notif('n', type: type, title: title, entity: entity);
    NotificationTarget? t(AppNotification x, {bool ct = false}) => notificationTargetFor(x, isClassTeacher: ct);

    test('every known type with a valid id', () {
      expect(t(n('message')), NotificationTarget(Routes.messageThreadOf(id)));
      expect(t(n('ptm')), NotificationTarget(Routes.ptmDetailOf(id)));
      expect(t(n('lesson_plan')), NotificationTarget(Routes.lessonPlanDetailOf(id)));
      expect(t(n('homework')), NotificationTarget(Routes.homeworkSubmissionsOf(id)));
      expect(t(n('substitution')), const NotificationTarget(Routes.fixtures, listFallback: true), reason: 'fixtures has no detail screen');
    });

    test('missing / invalid ids route to the module LIST, never a broken detail', () {
      for (final bad in ['', 'not-an-id', '123', ' ', '64e000000000000000000a0', '64e000000000000000000a0g']) {
        expect(t(n('message', entity: bad)), const NotificationTarget(Routes.homeMessages, listFallback: true), reason: bad);
        expect(t(n('ptm', entity: bad)), const NotificationTarget(Routes.ptm, listFallback: true));
        expect(t(n('lesson_plan', entity: bad)), const NotificationTarget(Routes.lessonPlans, listFallback: true));
        expect(t(n('homework', entity: bad)), const NotificationTarget(Routes.homework, listFallback: true));
      }
      expect(t(notif('n', type: 'message')), const NotificationTarget(Routes.homeMessages, listFallback: true), reason: 'relatedEntityId absent');
    });

    test('leave_status is overloaded: a class teacher\'s "New leave request" is a STUDENT leave, anything else is the teacher\'s own leave', () {
      expect(t(n('leave_status', title: 'New leave request'), ct: true), NotificationTarget(Routes.studentLeaveDetailOf(id)));
      expect(t(n('leave_status', title: ' new leave request '), ct: true), NotificationTarget(Routes.studentLeaveDetailOf(id)));
      expect(t(n('leave_status', title: 'New leave request', entity: 'bad'), ct: true), const NotificationTarget(Routes.studentLeaves, listFallback: true));
      expect(t(n('leave_status', title: 'Leave request approved'), ct: true), const NotificationTarget(Routes.leave, listFallback: true));
      expect(t(n('leave_status', title: 'Leave request rejected')), const NotificationTarget(Routes.leave, listFallback: true));
      expect(t(n('leave_status', title: 'New leave request')), const NotificationTarget(Routes.leave, listFallback: true), reason: 'not a class teacher: cannot be a student leave');
    });

    test('leave_decision belongs to guardians: a class teacher goes to the list, others stay', () {
      expect(t(n('leave_decision'), ct: true), NotificationTarget(Routes.studentLeaveDetailOf(id)));
      expect(t(n('leave_decision')), isNull);
    });

    test('other / unknown / guardian-only types stay in the inbox', () {
      for (final type in ['other', 'circular', 'consent', 'fee_due', 'result', 'behaviour', 'zzz_future', '', 'MESSAGE']) {
        expect(t(n(type)), isNull, reason: type);
      }
    });

    test('every produced route is a registered route pattern', () {
      final patterns = [...Routes.all, Routes.homeMessages].map((p) => RegExp('^${p.replaceAll(RegExp(r':\w+'), '[^/]+')}\$')).toList();
      for (final type in ['message', 'ptm', 'lesson_plan', 'homework', 'substitution', 'leave_status', 'leave_decision']) {
        for (final e in [id, '']) {
          final r = t(n(type, entity: e), ct: true)!.route;
          expect(patterns.any((p) => p.hasMatch(r)), isTrue, reason: '$type $e -> $r');
        }
      }
    });
  });

  group('message time (device timezone)', () {
    final now = DateTime(2026, 10, 8, 15, 0);
    test('relative', () {
      expect(relativeTime(now, now.subtract(const Duration(seconds: 20))), 'Just now');
      expect(relativeTime(now, now.add(const Duration(minutes: 5))), 'Just now', reason: 'a clock-skewed future time is not "in 5 min"');
      expect(relativeTime(now, now.subtract(const Duration(minutes: 5))), '5 min ago');
      expect(relativeTime(now, now.subtract(const Duration(hours: 3))), '3 h ago');
      expect(relativeTime(now, DateTime(2026, 10, 7, 23, 0)), 'Yesterday');
      expect(relativeTime(now, DateTime(2026, 10, 5, 9)), 'Mon');
      expect(relativeTime(now, DateTime(2026, 9, 1)), '1 Sep');
      expect(relativeTime(now, DateTime(2025, 12, 31)), '31 Dec 2025');
    });
    test('absolute and headings use local calendar days', () {
      expect(absoluteTime(DateTime(2026, 10, 8, 15, 7)), '8 Oct 2026, 3:07 PM');
      expect(dayHeading(now, DateTime(2026, 10, 8, 0, 1)), 'Today');
      expect(dayHeading(now, DateTime(2026, 10, 7, 23, 59)), 'Yesterday');
      expect(dayHeading(now, DateTime(2026, 10, 1)), 'Thu, 1 Oct');
      expect(bubbleTime(now, DateTime(2026, 10, 8, 9, 5)), '9:05 AM');
      expect(bubbleTime(now, DateTime(2026, 10, 7, 9, 5)), '7 Oct, 9:05 AM');
    });
    test('a UTC instant is shown in the device timezone', () {
      final utc = DateTime.utc(2026, 10, 8, 10, 0);
      expect(absoluteTime(utc), absoluteTime(utc.toLocal()));
      expect(dayKey(utc), dayKey(utc.toLocal()));
    });
  });
}
