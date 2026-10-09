// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/messages_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/new_thread_controller.dart';
import 'package:eldermin_teacher_app/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/controllers/student_leaves_controller.dart';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/notification_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/student_leave_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_home_repository.dart';
import '../support/fake_messaging_repository.dart';

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const oid1 = '64e000000000000000000a01';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMessagingRepository repo;
  late FakeHomeRepository home;
  late HomeBadgesController badges;
  final now = DateTime(2026, 10, 5, 9, 30);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeMessagingRepository();
    home = FakeHomeRepository();
  });
  tearDown(Get.reset);

  Future<dynamic> auth({bool classTeacher = false, List<Map<String, Object?>> assignments = const [cls5a]}) async {
    final h = await signedIn(classTeacher: classTeacher);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    badges = HomeBadgesController(repository: home, auth: h.auth, autoPoll: false);
    return h;
  }

  group('Inbox (MessagesController)', () {
    test('open list is the badge poller state: no second request, no second timer; rows exclude closed, unread first-class', () async {
      await auth();
      home.threads = () async => ThreadsResult(items: [thread('a', unread: true), thread('b'), thread('c', status: 'closed', unread: true)]);
      await badges.refreshAll();
      final c = MessagesController(repository: repo, badges: badges, clock: () => now);
      expect(c.rows.map((t) => t.id), ['a', 'b'], reason: 'a closed row is dropped even if a server ignored status=open');
      expect(badges.messagesUnread, 1);
      expect(repo.calls, isEmpty, reason: 'the open list never calls the messaging repository');
    });

    test('closed filter loads status=closed once; pull-to-refresh on open refreshes the shared poller state', () async {
      await auth();
      home.threads = () async => ThreadsResult(items: [thread('a')]);
      await badges.refreshAll();
      var closedLoads = 0;
      repo.threads = (status) async {
        closedLoads++;
        expect(status, 'closed');
        return ThreadsResult(items: [thread('z', status: 'closed')]);
      };
      final c = MessagesController(repository: repo, badges: badges);
      c.selectFilter(InboxFilter.closed);
      await pumpEventQueue();
      expect(c.rows.map((t) => t.id), ['z']);
      c.selectFilter(InboxFilter.open);
      c.selectFilter(InboxFilter.closed);
      expect(closedLoads, 1);
      home.threads = () async => ThreadsResult(items: [thread('a'), thread('n', unread: true)]);
      c.selectFilter(InboxFilter.open);
      await c.reload();
      expect(c.rows.map((t) => t.id), ['a', 'n']);
      expect(badges.messagesUnread, 1);
    });

    test('closed list failure -> error state, 404 -> not available, 403 -> forbidden', () async {
      await auth();
      final c = MessagesController(repository: repo, badges: badges);
      repo.threads = (_) async => fail7(500);
      c.selectFilter(InboxFilter.closed);
      await pumpEventQueue();
      expect(c.state.status, SectionStatus.error);
      repo.threads = (_) async => fail7(404);
      await c.loadClosed(userInitiated: true);
      expect(c.state.status, SectionStatus.unavailable);
      repo.threads = (_) async => fail7(403);
      await c.loadClosed(userInitiated: true);
      expect(c.state.status, SectionStatus.forbidden);
    });

    test('a list of exactly 100 rows is flagged as possibly cut (server limit)', () async {
      await auth();
      home.threads = () async => ThreadsResult(items: [for (var i = 0; i < 100; i++) thread('t$i')]);
      await badges.refreshAll();
      final c = MessagesController(repository: repo, badges: badges);
      expect(c.mayBeCut, isTrue);
      expect(badges.messagesUnreadCapped, isTrue);
    });

    test('badge sync hooks: addOpenThread puts a new thread on top; applyThreadChange edits only known rows', () async {
      await auth();
      home.threads = () async => ThreadsResult(items: [thread('a', unread: true)]);
      await badges.refreshAll();
      badges.addOpenThread(thread('n'));
      expect(badges.threads.value.data!.items.map((t) => t.id), ['n', 'a']);
      badges.applyThreadChange('missing', (t) => t.copyWith(staffHasUnread: true));
      badges.applyThreadChange('a', (t) => t.copyWith(staffHasUnread: false));
      expect(badges.messagesUnread, 0);
      badges.setNotificationUnread(-3);
      expect(badges.notificationUnread.value, 0);
    });
  });

  group('New conversation', () {
    final s1 = student(1);
    final outsider = student(30, grade: 'Grade 6', section: 'B');

    Future<NewThreadController> make({dynamic initial}) async {
      final h = await auth();
      final students = FakeStudentsRepository()..roster = (c) async => [s1, student(2)];
      return NewThreadController(repository: repo, students: students, auth: h.auth, badges: badges, initialStudent: initial)..onInit();
    }

    test('a preselected student of my class loads its guardians; one guardian is auto-selected', () async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      final c = await make(initial: s1);
      await pumpEventQueue();
      expect(c.student.value?.id, s1.id);
      expect(repo.calls, contains('guardians:${s1.id}'));
      expect(c.guardian.value?.userId, oid1);
    });

    test('a student outside my classes is never preselected', () async {
      final c = await make(initial: outsider);
      await pumpEventQueue();
      expect(c.student.value, isNull);
      expect(repo.calls.where((x) => x.startsWith('guardians')), isEmpty);
    });

    test('two guardians: the teacher must choose; empty list = empty state', () async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mr A'), const GuardianName(userId: '64e000000000000000000a02', name: 'Mrs A')];
      final c = await make(initial: s1);
      await pumpEventQueue();
      expect(c.guardian.value, isNull);
      expect(c.validate()['guardian'], isNotNull);
      c.selectGuardian(c.guardians.value.data!.last);
      expect(c.guardian.value!.name, 'Mrs A');
      repo.guardians = (id) async => [];
      await c.selectStudent(student(2));
      expect(c.guardians.value.status, SectionStatus.empty);
      expect(c.guardian.value, isNull);
    });

    test('403 on the guardians list shows the server text', () async {
      repo.guardians = (id) async => fail7(403, 'You do not teach this student.');
      final c = await make(initial: s1);
      await pumpEventQueue();
      expect(c.guardians.value.status, SectionStatus.forbidden);
      expect(c.guardiansDenied.value, 'You do not teach this student.');
    });

    test('validation: subject and message required, limits 200 / 4000, nothing is sent while invalid', () async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      final c = await make(initial: s1);
      await pumpEventQueue();
      var r = await c.submit();
      expect(r, isA<StartInvalid>());
      expect((r as StartInvalid).errors.keys, containsAll(['subject', 'message']));
      c.subjectC.text = 's' * 201;
      c.messageC.text = 'm' * 4001;
      r = await c.submit();
      expect((r as StartInvalid).errors['subject'], contains('200'));
      expect(r.errors['message'], contains('4000'));
      expect(repo.calls.where((x) => x.startsWith('create')), isEmpty);
    });

    test('success posts exactly the DTO fields, adds the thread to the open list and returns it; a second tap in flight is ignored', () async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      final gate = Completer<MessageThread>();
      NewThreadRequest? sent;
      repo.create = (r) {
        sent = r;
        return gate.future;
      };
      home.threads = () async => ThreadsResult(items: [thread('a')]);
      final c = await make(initial: s1);
      await badges.refreshAll();
      await pumpEventQueue();
      c.subjectC.text = '  Homework  ';
      c.messageC.text = ' Hello ';
      final first = c.submit();
      expect(await c.submit(), isA<StartIgnored>());
      gate.complete(thread('new1', subject: 'Homework'));
      final r = await first;
      expect(r, isA<StartCreated>());
      expect(sent!.toJson(), {'studentId': s1.id, 'guardianUserId': oid1, 'subject': 'Homework', 'firstMessage': 'Hello'});
      expect(badges.threads.value.data!.items.first.id, 'new1');
    });

    test('server 403 keeps every field and exposes the server text; dirty tracking drives the discard dialog', () async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      repo.create = (r) async => fail7(403, 'That person is not a registered guardian of this student.');
      final c = await make(initial: s1);
      await pumpEventQueue();
      expect(c.isDirty, isFalse);
      c.subjectC.text = 'Hi';
      c.messageC.text = 'Hello';
      expect(c.isDirty, isTrue);
      final r = await c.submit();
      expect(r, isA<StartFailed>());
      expect((r as StartFailed).failure.kind, ActionFailureKind.forbidden);
      expect(r.failure.serverMessage, 'That person is not a registered guardian of this student.');
      expect(c.subjectC.text, 'Hi');
      expect(c.messageC.text, 'Hello');
      expect(c.saving.value, isFalse);
    });
  });

  group('Notifications', () {
    NotificationsController make(h) => NotificationsController(repository: repo, badges: badges, auth: h.auth, clock: () => now);

    NotificationsPage page(List<AppNotification> items, {String? cursor, int unread = 2}) => NotificationsPage(items: items, nextCursor: cursor, unreadCount: unread);

    test('first page: grouped by LOCAL day, unread count goes to the bell badge', () async {
      final h = await auth();
      repo.notifications = (b, l, u) async => page([
            notif('n1', at: DateTime(2026, 10, 5, 8)),
            notif('n2', at: DateTime(2026, 10, 5, 7), read: true),
            notif('n3', at: DateTime(2026, 10, 4, 22)),
            notif('n4', at: DateTime(2026, 9, 1, 10), read: true),
          ], unread: 2);
      final c = make(h);
      await c.load();
      expect(c.groups.map((g) => g.heading), ['Today', 'Yesterday', 'Tue, 1 Sep']);
      expect(c.groups.first.items.map((n) => n.id), ['n1', 'n2']);
      expect(c.unreadCount.value, 2);
      expect(badges.notificationUnread.value, 2);
      expect(repo.calls.single, 'notifs:-:30:all');
    });

    test('empty, unavailable (404/501), forbidden, wrong shape', () async {
      final h = await auth();
      final c = make(h);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.notifications = (b, l, u) async => fail7(404);
      await c.load();
      expect(c.state.value.status, SectionStatus.unavailable);
      repo.notifications = (b, l, u) async => fail7(501);
      await c.load();
      expect(c.state.value.status, SectionStatus.unavailable);
      repo.notifications = (b, l, u) async => fail7(403);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      repo.notifications = (b, l, u) async => throw UnexpectedResponseShapeForTest();
      await c.load();
      expect(c.state.value.status, SectionStatus.error);
    });

    test('cursor paging: loadMore sends `before`, appends without duplicates and stops at the end', () async {
      final h = await auth();
      repo.notifications = (before, l, u) async {
        if (before == null) return page([notif('n1'), notif('n2')], cursor: '2026-10-05T07:00:00.000Z');
        if (before == '2026-10-05T07:00:00.000Z') return page([notif('n2'), notif('n3')], cursor: '2026-10-04T07:00:00.000Z');
        return page([notif('n4')]);
      };
      final c = make(h);
      await c.load();
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.items.map((n) => n.id), ['n1', 'n2', 'n3'], reason: 'the repeated n2 is dropped');
      await c.loadMore();
      expect(c.items.map((n) => n.id), ['n1', 'n2', 'n3', 'n4']);
      expect(c.hasMore, isFalse);
      await c.loadMore();
      expect(repo.calls.where((x) => x.startsWith('notifs')).length, 3, reason: 'no request after the end');
    });

    test('a server that returns the same cursor forever cannot loop', () async {
      final h = await auth();
      repo.notifications = (before, l, u) async => page([notif('n${before ?? 0}')], cursor: 'same');
      final c = make(h);
      await c.load();
      await c.loadMore();
      await c.loadMore();
      expect(c.hasMore, isFalse);
    });

    test('loadMore is not re-entrant and a failure offers retry without losing the list', () async {
      final h = await auth();
      final gate = Completer<NotificationsPage>();
      var calls = 0;
      repo.notifications = (before, l, u) {
        if (before == null) return Future.value(page([notif('n1')], cursor: 'c1'));
        calls++;
        return gate.future;
      };
      final c = make(h);
      await c.load();
      final a = c.loadMore();
      await c.loadMore();
      expect(calls, 1);
      gate.completeError(ApiException('boom', statusCode: 500));
      await a;
      expect(c.moreFailed.value, isTrue);
      expect(c.items, hasLength(1));
      expect(c.hasMore, isTrue);
      repo.notifications = (before, l, u) async => page([notif('n2')]);
      await c.loadMore();
      expect(c.moreFailed.value, isFalse);
      expect(c.items.map((n) => n.id), ['n1', 'n2']);
    });

    test('unread filter sends unread=true and restarts from the first page', () async {
      final h = await auth();
      repo.notifications = (b, l, u) async => page(u ? [notif('u1')] : [notif('n1'), notif('u1')], unread: 1);
      final c = make(h);
      await c.load();
      await c.setUnreadOnly(true);
      expect(c.items.map((n) => n.id), ['u1']);
      expect(repo.calls.last, 'notifs:-:30:unread');
    });

    test('mark read is optimistic: list, count and bell change at once; a failure rolls back and says so', () async {
      final h = await auth();
      repo.notifications = (b, l, u) async => page([notif('n1'), notif('n2')], unread: 2);
      final gate = Completer<void>();
      repo.markNotification = (id) => gate.future;
      final c = make(h);
      await c.load();
      final f = c.markRead('n1');
      expect(c.items.first.isRead, isTrue);
      expect(c.unreadCount.value, 1);
      expect(badges.notificationUnread.value, 1);
      gate.completeError(ApiException('boom', statusCode: 500));
      await f;
      expect(c.items.first.isRead, isFalse);
      expect(c.unreadCount.value, 2);
      expect(badges.notificationUnread.value, 2);
      expect(c.actionFailure.value, isNotNull);
      // a 404 (deleted meanwhile) is not worth rolling back
      repo.markNotification = (id) async => fail7(404, 'Notification not found');
      await c.markRead('n2');
      expect(c.items.last.isRead, isTrue);
    });

    test('mark all read: everything read and counts 0 immediately; failure restores; nothing to do when already clean', () async {
      final h = await auth();
      repo.notifications = (b, l, u) async => page([notif('n1'), notif('n2'), notif('n3', read: true)], unread: 2);
      final c = make(h);
      await c.load();
      repo.markAll = () async => fail7(500);
      expect(await c.markAllRead(), isFalse);
      expect(c.items.where((n) => !n.isRead), hasLength(2));
      expect(badges.notificationUnread.value, 2);
      expect(c.actionFailure.value, isNotNull);
      repo.markAll = () async => 2;
      expect(await c.markAllRead(), isTrue);
      expect(c.items.every((n) => n.isRead), isTrue);
      expect(c.unreadCount.value, 0);
      expect(badges.notificationUnread.value, 0);
      expect(await c.markAllRead(), isFalse, reason: 'nothing unread: no request');
      expect(repo.calls.where((x) => x == 'nreadall'), hasLength(2));
    });

    test('a refresh that was already in flight when "mark all read" ran cannot bring the unread state back', () async {
      final h = await auth();
      var first = true;
      final gate = Completer<NotificationsPage>();
      repo.notifications = (b, l, u) => first ? Future.value(page([notif('n1'), notif('n2')], unread: 2)) : gate.future;
      final c = make(h);
      await c.load();
      first = false;
      final refresh = c.load(); // in flight, will answer with the OLD unread state
      repo.markAll = () async => 2;
      expect(await c.markAllRead(), isTrue);
      gate.complete(page([notif('n1'), notif('n2')], unread: 2));
      await refresh;
      expect(c.items.every((n) => n.isRead), isTrue);
      expect(c.unreadCount.value, 0);
      expect(badges.notificationUnread.value, 0);
    });

    test('tap = mark read + the deep-link target; unknown types and bad ids never throw', () async {
      final h = await auth(classTeacher: true);
      repo.notifications = (b, l, u) async => page([
            notif('n1', type: 'message', entity: oid1),
            notif('n2', type: 'zzz_future', entity: 'not-an-id'),
            notif('n3', type: 'leave_status', title: 'New leave request', entity: oid1),
            notif('n4', type: 'message'),
          ], unread: 4);
      final c = make(h);
      await c.load();
      expect(c.tap(c.items[0])?.route, Routes.messageThreadOf(oid1));
      expect(c.items[0].isRead, isTrue);
      expect(c.tap(c.items[1]), isNull);
      expect(c.items[1].isRead, isTrue, reason: 'unknown type: still marked read, stays in the inbox');
      expect(c.tap(c.items[2])?.route, Routes.studentLeaveDetailOf(oid1));
      expect(c.tap(c.items[3])?.route, Routes.homeMessages, reason: 'missing id -> the inbox list');
    });

    test('a failed pull-to-refresh keeps the list and reports; the first load failure is an error state', () async {
      final h = await auth();
      repo.notifications = (b, l, u) async => page([notif('n1')]);
      final c = make(h);
      await c.load();
      repo.notifications = (b, l, u) async => fail7(500);
      await c.reload();
      expect(c.items, hasLength(1));
      expect(c.refreshError.value, isNotNull);
      final c2 = make(h);
      await c2.load();
      expect(c2.state.value.status, SectionStatus.error);
    });
  });

  group('Student leaves', () {
    StudentLeavesController make(h) => StudentLeavesController(repository: repo, auth: h.auth);

    test('not a class teacher: nothing is requested', () async {
      final h = await auth();
      final c = make(h);
      expect(c.allowed, isFalse);
      c.onReady();
      await c.loadTab(LeaveStatus.pending);
      expect(repo.calls, isEmpty);
      expect(await c.review('x', LeaveStatus.approved), isA<ReviewIgnored>());
    });

    test('tabs load with their own status; counts come from the loaded rows', () async {
      final h = await auth(classTeacher: true);
      repo.leaves = (s, l) async => switch (s) {
            LeaveStatus.pending => [leaveReq('p1'), leaveReq('p2')],
            LeaveStatus.approved => [leaveReq('a1', status: 'approved', by: 'Clara')],
            _ => [],
          };
      final c = make(h);
      await c.loadTab(LeaveStatus.pending);
      expect(c.countOf(LeaveStatus.pending), 2);
      expect(c.countOf(LeaveStatus.approved), isNull, reason: 'not loaded yet');
      c.selectTab(LeaveStatus.approved);
      await pumpEventQueue();
      c.selectTab(LeaveStatus.rejected);
      await pumpEventQueue();
      expect(c.countOf(LeaveStatus.approved), 1);
      expect(c.countOf(LeaveStatus.rejected), 0);
      expect(c.stateOf(LeaveStatus.rejected).status, SectionStatus.empty);
      expect(repo.calls, ['leaves:pending', 'leaves:approved', 'leaves:rejected']);
    });

    test('approve: remarks trimmed and sent, the request moves from Pending to Approved, counts follow', () async {
      final h = await auth(classTeacher: true);
      repo.leaves = (s, l) async => s == LeaveStatus.pending ? [leaveReq('p1'), leaveReq('p2')] : [];
      String? sentRemarks;
      repo.review = (id, s, r) async {
        sentRemarks = r;
        return leaveReq(id, status: s.wire, by: 'Tess Teacher', note: r, decided: DateTime.utc(2026, 10, 8));
      };
      final c = make(h);
      await c.loadTab(LeaveStatus.pending);
      await c.loadTab(LeaveStatus.approved);
      final r = await c.review('p1', LeaveStatus.approved, remarks: '  Get well soon  ');
      expect(r, isA<ReviewDone>());
      expect(sentRemarks, 'Get well soon');
      expect(c.countOf(LeaveStatus.pending), 1);
      expect(c.countOf(LeaveStatus.approved), 1);
      expect(c.find('p1')!.approverName, 'Tess Teacher');
      expect(c.reviewing.value, isNull);
    });

    test('a second review while one is in flight is ignored', () async {
      final h = await auth(classTeacher: true);
      repo.leaves = (s, l) async => [leaveReq('p1'), leaveReq('p2')];
      final gate = Completer<StudentLeaveRequest>();
      repo.review = (id, s, r) => gate.future;
      final c = make(h);
      await c.loadTab(LeaveStatus.pending);
      final first = c.review('p1', LeaveStatus.approved);
      expect(await c.review('p2', LeaveStatus.rejected), isA<ReviewIgnored>());
      gate.complete(leaveReq('p1', status: 'approved'));
      await first;
      expect(repo.calls.where((x) => x.startsWith('review')), hasLength(1));
    });

    test('409 already decided: lists are re-read and the result carries who / when decided', () async {
      final h = await auth(classTeacher: true);
      var decided = false;
      repo.leaves = (s, l) async {
        if (!decided) return s == LeaveStatus.pending ? [leaveReq('p1')] : [];
        return switch (s) {
          LeaveStatus.approved => [leaveReq('p1', status: 'approved', by: 'Clara Classteacher', decided: DateTime.utc(2026, 10, 8, 7))],
          _ => [],
        };
      };
      repo.review = (id, s, r) async {
        decided = true;
        return fail7(409, 'This request was already approved.');
      };
      final c = make(h);
      await c.loadTab(LeaveStatus.pending);
      final r = await c.review('p1', LeaveStatus.rejected);
      expect(r, isA<ReviewConflict>());
      expect((r as ReviewConflict).serverText, 'This request was already approved.');
      expect(r.decided?.approverName, 'Clara Classteacher');
      expect(r.decided?.status, LeaveStatus.approved);
      expect(c.countOf(LeaveStatus.pending), 0);
      expect(c.countOf(LeaveStatus.approved), 1);
    });

    test('403 shows the server text and keeps the list; 404 / validation are failures too', () async {
      final h = await auth(classTeacher: true);
      repo.leaves = (s, l) async => [leaveReq('p1')];
      repo.review = (id, s, r) async => fail7(403, 'This student is not in your class.');
      final c = make(h);
      await c.loadTab(LeaveStatus.pending);
      final r = await c.review('p1', LeaveStatus.approved);
      expect(r, isA<ReviewFailed>());
      expect((r as ReviewFailed).failure.kind, ActionFailureKind.forbidden);
      expect(r.failure.serverMessage, 'This student is not in your class.');
      expect(c.countOf(LeaveStatus.pending), 1);
      expect(c.reviewing.value, isNull, reason: 'the guard is released after a failure');
      expect(await c.review('p1', LeaveStatus.approved, remarks: 'x' * 1001), isA<ReviewFailed>());
      expect(repo.calls.where((x) => x.startsWith('review')), hasLength(1), reason: 'over-long remarks never reach the server');
    });

    test('resolve finds a request in any status list (deep link) and gives up cleanly when it is not listed', () async {
      final h = await auth(classTeacher: true);
      repo.leaves = (s, l) async => s == LeaveStatus.rejected ? [leaveReq('r1', status: 'rejected', by: 'Clara')] : [];
      final c = make(h);
      expect((await c.resolve('r1'))?.status, LeaveStatus.rejected);
      expect(await c.resolve('unknown'), isNull);
    });

    test('list errors: 403 (not class teacher) -> forbidden, 404/501 -> not available, a wrong body -> error', () async {
      final h = await auth(classTeacher: true);
      final c = make(h);
      repo.leaves = (s, l) async => fail7(403, 'Only class teachers can review student leave requests.');
      await c.loadTab(LeaveStatus.pending);
      expect(c.stateOf(LeaveStatus.pending).status, SectionStatus.forbidden);
      repo.leaves = (s, l) async => fail7(501);
      await c.loadTab(LeaveStatus.pending);
      expect(c.stateOf(LeaveStatus.pending).status, SectionStatus.unavailable);
      repo.leaves = (s, l) async => throw UnexpectedResponseShapeForTest();
      await c.loadTab(LeaveStatus.pending);
      expect(c.stateOf(LeaveStatus.pending).status, SectionStatus.error);
    });
  });
}

/// Stands in for response_shape's UnexpectedResponseShape without importing the implementation detail.
class UnexpectedResponseShapeForTest extends ApiException {
  UnexpectedResponseShapeForTest() : super('Something went wrong loading notifications — try again.');
}
