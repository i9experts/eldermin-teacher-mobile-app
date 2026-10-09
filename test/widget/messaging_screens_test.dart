// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/chat_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/messages_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/new_thread_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/message_new_screen.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/message_thread_screen.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/messages_screen.dart';
import 'package:eldermin_teacher_app/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:eldermin_teacher_app/app/modules/notifications/views/notifications_screen.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/controllers/student_leaves_controller.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/views/student_leave_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/views/student_leaves_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/notification_models.dart';
import 'package:eldermin_teacher_app/core/models/messaging/student_leave_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/messaging_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_home_repository.dart';
import '../support/fake_messaging_repository.dart';

ApiException err(int status, [String message = 'error']) => ApiException(message, statusCode: status);

const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const oid1 = '64e000000000000000000a01';

void main() {
  late FakeMessagingRepository repo;
  late FakeHomeRepository home;
  late HomeBadgesController badges;
  late FakePoller poller;
  final visited = <String>[];

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeMessagingRepository();
    home = FakeHomeRepository();
    poller = FakePoller();
    visited.clear();
  });
  tearDown(Get.reset);

  Future<dynamic> auth(WidgetTester t, {bool classTeacher = false}) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn(classTeacher: classTeacher);
      h.api.assignments = const [cls5a];
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    badges = HomeBadgesController(repository: home, auth: h.auth, autoPoll: false);
    Get.put<HomeBadgesController>(badges);
    return h;
  }

  /// A GetMaterialApp whose named routes just record where the app went (the real screens are covered by their own tests).
  Future<void> show(WidgetTester t, Widget home) async {
    await t.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    Widget stub(String name) => Scaffold(body: Text('went:$name'));
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      home: home,
      getPages: [
        for (final r in [...Routes.all, Routes.homeMessages]) GetPage(name: r, page: () => stub(r)),
      ],
    ));
    await t.pump();
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
  }

  group('Inbox', () {
    Future<MessagesController> boot(WidgetTester t, {ThreadsResult? open, Object? error}) async {
      await auth(t);
      home.threads = () async => error != null ? throw error : open!;
      final c = Get.put(MessagesController(repository: repo, badges: badges, clock: () => DateTime.utc(2026, 10, 5, 9)));
      await show(t, const Scaffold(body: MessagesScreen(embedded: true)));
      await t.runAsync(() => badges.refreshThreads());
      await settle(t);
      return c;
    }

    testWidgets('lists conversations: guardian, student, subject, preview, unread dot, closed tag, relative time', (t) async {
      await boot(t, open: ThreadsResult(items: [
        thread('a', guardian: 'Mrs Malik', student: 'Zara Malik', subject: 'Homework', preview: 'Thank you ma\'am', unread: true, at: DateTime.utc(2026, 10, 5, 8, 48)),
        thread('b', guardian: 'Mr Ali', preview: 'See you Thursday', at: DateTime.utc(2026, 10, 4, 9)),
      ]));
      expect(find.text('Mrs Malik'), findsOneWidget);
      expect(find.text('re Zara Malik · Homework'), findsWidgets);
      expect(find.text('Thank you ma\'am'), findsOneWidget);
      expect(find.byKey(const Key('unread_a')), findsOneWidget);
      expect(find.byKey(const Key('unread_b')), findsNothing);
      expect(find.text('12 min ago'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('empty open list and empty closed list have their own text', (t) async {
      final c = await boot(t, open: const ThreadsResult());
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No open conversations'), findsOneWidget);
      repo.threads = (_) async => const ThreadsResult();
      await t.tap(find.text('Closed'));
      await t.runAsync(() => c.loadClosed());
      await settle(t);
      expect(find.text('No closed conversations'), findsOneWidget);
    });

    testWidgets('error shows the message and Try again reloads', (t) async {
      await boot(t, error: err(500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      home.threads = () async => ThreadsResult(items: [thread('a')]);
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.byKey(const Key('thread_a')), findsOneWidget);
    });

    testWidgets('403 -> "You don\'t have access"; 404 -> "not available on this server yet"', (t) async {
      await boot(t, error: err(403));
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      await t.runAsync(() async {
        home.threads = () async => fail7(404);
        await badges.refreshThreads(userInitiated: true);
      });
      await settle(t);
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
      expect(find.text('Not available on this server yet'), findsOneWidget);
    });

    testWidgets('loading state is a shimmer', (t) async {
      await auth(t);
      final never = Completer<ThreadsResult>();
      home.threads = () => never.future;
      Get.put(MessagesController(repository: repo, badges: badges));
      await show(t, const Scaffold(body: MessagesScreen(embedded: true)));
      unawaited(badges.refreshThreads());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
    });

    testWidgets('pull to refresh re-reads the open threads', (t) async {
      await boot(t, open: ThreadsResult(items: [thread('a')]));
      home.threads = () async => ThreadsResult(items: [thread('a'), thread('z', guardian: 'Newcomer')]);
      await t.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Newcomer'), findsOneWidget);
    });

    testWidgets('tapping a row opens the chat route; + opens the new-message route', (t) async {
      await boot(t, open: ThreadsResult(items: [thread('a')]));
      await t.tap(find.byKey(const Key('messages_new')));
      await settle(t);
      expect(find.text('went:${Routes.messageNew}'), findsOneWidget);
      Get.back();
      await settle(t);
      await t.tap(find.byKey(const Key('thread_a')));
      await settle(t);
      expect(Get.currentRoute, Routes.messageThreadOf('a'));
    });
  });

  group('Chat', () {
    Future<ChatController> boot(WidgetTester t, {ThreadMessages Function(String id)? data, Object? error, bool unread = false}) async {
      await auth(t);
      repo.messages = (id) async => error != null ? throw error : (data ?? (i) => ThreadMessages(thread: thread(i, unread: unread), messages: [serverMsg('m1', 'Assalamu alaikum', at: DateTime.utc(2026, 10, 5, 8)), serverMsg('m2', 'Walaikum assalam', mine: true, at: DateTime.utc(2026, 10, 5, 8, 5))]))(id);
      final c = Get.put(ChatController(threadId: 't1', repository: repo, badges: badges, observeLifecycle: false, timerFactory: poller.create), tag: 't1');
      await show(t, const MessageThreadScreen(threadId: 't1'));
      await t.runAsync(() => c.loadThread());
      await settle(t);
      return c;
    }

    testWidgets('header, bubbles on the correct sides, composer', (t) async {
      await boot(t);
      expect(find.text('Mrs Malik'), findsOneWidget);
      expect(find.text('Assalamu alaikum'), findsOneWidget);
      expect(find.text('Walaikum assalam'), findsOneWidget);
      final theirs = t.getTopLeft(find.text('Assalamu alaikum')).dx, mine = t.getTopLeft(find.text('Walaikum assalam')).dx;
      expect(mine, greaterThan(theirs));
      expect(find.byKey(const Key('chat_input')), findsOneWidget);
      expect(find.byKey(const Key('chat_closed_banner')), findsNothing);
    });

    testWidgets('a 500-message thread opens at the NEWEST message (lazy layout must not stop the jump short)', (t) async {
      await boot(t, data: (id) => ThreadMessages(thread: thread(id), messages: [for (var i = 1; i <= 500; i++) serverMsg('m$i', 'Long msg $i', mine: i.isEven, at: DateTime.utc(2026, 10, 5, 8).add(Duration(minutes: i)))]));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Long msg 500'), findsOneWidget);
    });

    testWidgets('typing and tapping send shows the message at once (Sending…), clears the field; a double tap sends once', (t) async {
      final c = await boot(t);
      final gate = Completer<ChatMessage>();
      repo.send = (id, body) => gate.future;
      await t.enterText(find.byKey(const Key('chat_input')), 'On my way');
      await t.pump();
      await t.tap(find.byKey(const Key('chat_send')));
      await t.tap(find.byKey(const Key('chat_send')), warnIfMissed: false);
      await t.pump();
      expect(find.text('On my way'), findsOneWidget);
      expect(find.byKey(const Key('msg_sending')), findsOneWidget);
      expect(c.composer.text, isEmpty);
      expect(repo.sentBodies, ['On my way']);
      gate.complete(serverMsg('m3', 'On my way', mine: true));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.byKey(const Key('msg_sending')), findsNothing);
      expect(find.text('On my way'), findsOneWidget);
    });

    testWidgets('failed send: "Not sent" with Retry and Remove; Retry succeeds', (t) async {
      await boot(t);
      var fail = true;
      repo.send = (id, body) async => fail ? fail7(503) : serverMsg('m9', body, mine: true);
      await t.enterText(find.byKey(const Key('chat_input')), 'Please call');
      await t.pump();
      await t.tap(find.byKey(const Key('chat_send')));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.byKey(const Key('msg_failed')), findsOneWidget);
      expect(find.textContaining('Not sent'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Retry'));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.byKey(const Key('msg_failed')), findsNothing);
      expect(find.text('Please call'), findsOneWidget);
    });

    testWidgets('closed thread: read-only composer with the explanation, no input', (t) async {
      await boot(t, data: (id) => ThreadMessages(thread: thread(id, status: 'closed'), messages: [serverMsg('m1', 'Bye')]));
      expect(find.byKey(const Key('chat_closed_banner')), findsOneWidget);
      expect(find.textContaining('This conversation is closed'), findsOneWidget);
      expect(find.byKey(const Key('chat_input')), findsNothing);
      expect(find.byKey(const Key('chat_menu')), findsNothing);
    });

    testWidgets('a 409 on send turns the composer read-only and keeps the unsent text visible without Retry', (t) async {
      await boot(t);
      repo.send = (id, body) async => fail7(409, 'This conversation is closed.');
      await t.enterText(find.byKey(const Key('chat_input')), 'Late message');
      await t.pump();
      await t.tap(find.byKey(const Key('chat_send')));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.byKey(const Key('chat_closed_banner')), findsOneWidget);
      expect(find.text('Late message'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('Close conversation asks first; Cancel changes nothing, Close makes it read-only', (t) async {
      final c = await boot(t);
      await t.tap(find.byKey(const Key('chat_menu')));
      await settle(t);
      await t.tap(find.byKey(const Key('chat_close')));
      await settle(t);
      expect(find.text('Close this conversation?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
      await settle(t);
      expect(c.closed.value, isFalse);
      expect(repo.calls.where((x) => x.startsWith('close')), isEmpty);
      await t.tap(find.byKey(const Key('chat_menu')));
      await settle(t);
      await t.tap(find.byKey(const Key('chat_close')));
      await settle(t);
      await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.byKey(const Key('chat_closed_banner')), findsOneWidget);
      expect(repo.calls, contains('close:t1'));
      await t.pump(const Duration(seconds: 3)); // the "Conversation closed" toast
    });

    testWidgets('not found / not deployed / forbidden / error + retry / loading', (t) async {
      await boot(t, error: err(404, 'Thread not found'));
      expect(find.byKey(const Key('chat_not_found')), findsOneWidget);
      Get.reset();
      await boot(t, error: err(404, 'Cannot GET /api/v1/staff-portal/threads/t1/messages'));
      expect(find.byKey(const Key('chat_unavailable')), findsOneWidget);
      Get.reset();
      await boot(t, error: err(403));
      expect(find.byKey(const Key('chat_forbidden')), findsOneWidget);
      Get.reset();
      final c = await boot(t, error: err(500));
      expect(find.byKey(const Key('chat_error')), findsOneWidget);
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'Recovered')]);
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(find.text('Recovered'), findsOneWidget);
      expect(c.load.value.hasData, isTrue);
    });

    testWidgets('a poll appends a new guardian message; the typed text and a "new messages" chip stay', (t) async {
      final c = await boot(t);
      await t.enterText(find.byKey(const Key('chat_input')), 'draft in progress');
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'Assalamu alaikum'), serverMsg('m2', 'Walaikum assalam', mine: true), serverMsg('m3', 'One more question')]);
      await t.runAsync(() => c.poll());
      await settle(t);
      expect(find.text('One more question'), findsOneWidget);
      expect(find.text('draft in progress'), findsOneWidget);
    });

    testWidgets('a failing poll shows the quiet banner but keeps the conversation', (t) async {
      final c = await boot(t);
      repo.messages = (id) async => fail7(500);
      await t.runAsync(() => c.poll());
      await settle(t);
      expect(find.byKey(const Key('chat_poll_failing')), findsOneWidget);
      expect(find.text('Assalamu alaikum'), findsOneWidget);
    });

    testWidgets('the controller the screen creates is removed with the screen: its poll timer is cancelled (no pending timer is left)', (t) async {
      await auth(t);
      Get.put<MessagingRepository>(repo);
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'Hi')]);
      await show(t, const MessageThreadScreen(threadId: 't1'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(Get.isRegistered<ChatController>(tag: 't1'), isTrue);
      expect(Get.find<ChatController>(tag: 't1').isPolling, isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(Get.isRegistered<ChatController>(tag: 't1'), isFalse);
    });
  });

  group('New message', () {
    final s1 = student(1);
    Future<NewThreadController> boot(WidgetTester t, {dynamic initial}) async {
      final h = await auth(t);
      final students = FakeStudentsRepository()..roster = (c) async => [s1, student(2)];
      final c = Get.put(NewThreadController(repository: repo, students: students, auth: h.auth, badges: badges, initialStudent: initial));
      await show(t, const MessageNewScreen());
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      return c;
    }

    testWidgets('from Student 360: student preselected, guardian names (no contact data), subject + message -> POST -> opens the chat', (t) async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik'), const GuardianName(userId: '64e000000000000000000a02', name: 'Mr Malik')];
      await boot(t, initial: s1);
      expect(find.byKey(const Key('new_selected_student')), findsOneWidget);
      expect(find.text('Mrs Malik'), findsOneWidget);
      expect(find.textContaining('phone number and email are not shown'), findsOneWidget);
      await t.tap(find.byKey(const Key('guardian_$oid1')));
      await t.enterText(find.byKey(const Key('new_subject')), 'Homework');
      await t.enterText(find.byKey(const Key('new_message')), 'Hello Mrs Malik');
      await t.pump();
      await t.tap(find.byKey(const Key('new_submit')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(repo.calls, contains('create:${s1.id}:$oid1'));
      expect(Get.currentRoute, Routes.messageThreadOf('new1'));
    });

    testWidgets('from the inbox: pick a student in the sheet, then the guardian appears', (t) async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      await boot(t);
      expect(find.byKey(const Key('new_selected_student')), findsNothing);
      await t.tap(find.byKey(const Key('new_student_picker')));
      await settle(t);
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      await t.tap(find.text('First2 Last2'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.byKey(const Key('new_selected_student')), findsOneWidget);
      expect(find.text('Mrs Malik'), findsOneWidget);
    });

    testWidgets('no guardian account / 403 server text / validation messages', (t) async {
      repo.guardians = (id) async => [];
      await boot(t, initial: s1);
      expect(find.byKey(const Key('new_guardians_empty')), findsOneWidget);
      Get.reset();
      repo.guardians = (id) async => fail7(403, 'You do not teach this student.');
      await boot(t, initial: s1);
      expect(find.byKey(const Key('new_guardians_denied')), findsOneWidget);
      expect(find.text('You do not teach this student.'), findsOneWidget);
      await t.tap(find.byKey(const Key('new_submit')));
      await t.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(repo.calls.where((x) => x.startsWith('create')), isEmpty);
    });

    testWidgets('a rejected send keeps the form and shows the server text', (t) async {
      repo.guardians = (id) async => [const GuardianName(userId: oid1, name: 'Mrs Malik')];
      repo.create = (r) async => fail7(403, 'That person is not a registered guardian of this student.');
      await boot(t, initial: s1);
      await t.enterText(find.byKey(const Key('new_subject')), 'Hi');
      await t.enterText(find.byKey(const Key('new_message')), 'Hello');
      await t.pump();
      await t.tap(find.byKey(const Key('new_submit')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.textContaining('not a registered guardian'), findsWidgets);
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('Notifications', () {
    Future<NotificationsController> boot(WidgetTester t, {List<AppNotification>? items, String? cursor, int unread = 2, Object? error, bool classTeacher = false}) async {
      final h = await auth(t, classTeacher: classTeacher);
      repo.notifications = (b, l, u) async => error != null ? throw error : NotificationsPage(items: items ?? [], nextCursor: cursor, unreadCount: unread);
      final c = Get.put(NotificationsController(repository: repo, badges: badges, auth: h.auth, clock: () => DateTime(2026, 10, 5, 9)));
      await show(t, const NotificationsScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      return c;
    }

    testWidgets('grouped by day with unread dots; mark-all-read enables only while unread exist and updates everything + the bell count', (t) async {
      final c = await boot(t, items: [
        notif('n1', title: 'New message from Mrs Malik', at: DateTime(2026, 10, 5, 8)),
        notif('n2', type: 'substitution', title: 'Substitution assigned', read: true, at: DateTime(2026, 10, 5, 7)),
        notif('n3', type: 'ptm', title: 'Meeting requested', at: DateTime(2026, 10, 4, 20)),
      ]);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.byKey(const Key('notif_unread_n1')), findsOneWidget);
      expect(find.byKey(const Key('notif_unread_n2')), findsNothing);
      expect(find.textContaining('1 h ago'), findsWidgets);
      expect(find.textContaining('8:00 AM'), findsWidgets);
      expect(badges.notificationUnread.value, 2);
      await t.tap(find.byKey(const Key('notif_mark_all')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.byKey(const Key('notif_unread_n1')), findsNothing);
      expect(find.byKey(const Key('notif_unread_n3')), findsNothing);
      expect(badges.notificationUnread.value, 0);
      expect(c.unreadCount.value, 0);
      final button = t.widget<TextButton>(find.byKey(const Key('notif_mark_all')));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping a message notification marks it read and opens the thread; an unknown type stays on the inbox', (t) async {
      await boot(t, items: [
        notif('n1', type: 'message', entity: oid1, title: 'New message'),
        notif('n2', type: 'zzz_future', entity: 'not-an-id', title: 'Something new'),
      ]);
      await t.tap(find.text('Something new'));
      await settle(t);
      expect(find.text('Something new'), findsOneWidget, reason: 'still on the inbox');
      expect(find.byKey(const Key('notif_unread_n2')), findsNothing, reason: 'but read');
      await t.tap(find.text('New message'));
      await settle(t);
      expect(Get.currentRoute, Routes.messageThreadOf(oid1));
      expect(repo.calls, containsAll(['nread:n1', 'nread:n2']));
    });

    testWidgets('a message notification with a malformed id selects the Messages tab of the shell instead of pushing a second shell', (t) async {
      final shell = Get.put(HomeShellController());
      await boot(t, items: [notif('n3', type: 'message', entity: 'not-an-id', title: 'Broken id message')]);
      await t.tap(find.text('Broken id message'));
      await settle(t);
      expect(shell.tabIndex.value, HomeShellController.messagesTab);
      expect(t.takeException(), isNull);
    });

    testWidgets('infinite scroll: reaching the end loads the next cursor page; the end marker shows when done', (t) async {
      final h = await auth(t);
      repo.notifications = (before, l, u) async => before == null
          ? NotificationsPage(items: [for (var i = 0; i < 14; i++) notif('a$i', title: 'Item a$i', at: DateTime(2026, 10, 5, 8).subtract(Duration(hours: i)))], nextCursor: 'cur1', unreadCount: 0)
          : NotificationsPage(items: [notif('b1', title: 'Older item', at: DateTime(2026, 9, 20))], unreadCount: 0);
      final c = Get.put(NotificationsController(repository: repo, badges: badges, auth: h.auth, clock: () => DateTime(2026, 10, 5, 9)));
      await show(t, const NotificationsScreen());
      await t.runAsync(() => c.load());
      await settle(t);
      expect(find.text('Older item'), findsNothing);
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await settle(t);
      expect(find.text('Older item'), findsOneWidget);
      expect(find.byKey(const Key('notif_end')), findsOneWidget);
      expect(repo.calls.where((x) => x.startsWith('notifs:cur1')), hasLength(1));
    });

    testWidgets('empty / unread-only empty / error + retry / 403 / 404', (t) async {
      await boot(t, items: []);
      expect(find.text('No notifications yet'), findsOneWidget);
      Get.reset();
      await boot(t, error: err(500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      Get.reset();
      await boot(t, error: err(403));
      expect(find.text("You don't have access"), findsOneWidget);
      Get.reset();
      await boot(t, error: err(404));
      expect(find.text('Not available on this server yet'), findsOneWidget);
      Get.reset();
      await boot(t, items: [notif('n1')], unread: 1);
      repo.notifications = (b, l, u) async => const NotificationsPage(items: [], unreadCount: 0);
      await t.tap(find.text('Unread'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.text('No unread notifications'), findsOneWidget);
    });

    testWidgets('loading state is a shimmer', (t) async {
      final h = await auth(t);
      repo.notifications = (b, l, u) => Completer<NotificationsPage>().future;
      final c = Get.put(NotificationsController(repository: repo, badges: badges, auth: h.auth));
      await show(t, const NotificationsScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
    });
  });

  group('Student leave requests', () {
    Future<StudentLeavesController> boot(WidgetTester t, {bool classTeacher = true, Widget screen = const StudentLeavesScreen(), Map<LeaveStatus, List<StudentLeaveRequest>>? data, Object? error}) async {
      final h = await auth(t, classTeacher: classTeacher);
      repo.leaves = (s, l) async => error != null ? throw error : (data?[s] ?? []);
      final c = Get.put(StudentLeavesController(repository: repo, auth: h.auth));
      await show(t, screen);
      await t.runAsync(() => c.loadTab(LeaveStatus.pending));
      await settle(t);
      return c;
    }

    final all = {
      LeaveStatus.pending: [leaveReq('p1'), leaveReq('p2', student: 'Omar Siddiqui')],
      LeaveStatus.approved: [leaveReq('a1', status: 'approved', by: 'Clara Classteacher', note: 'Get well soon', decided: DateTime.utc(2026, 10, 7, 7))],
      LeaveStatus.rejected: <StudentLeaveRequest>[],
    };

    testWidgets('non class teachers see an explanation and nothing is requested', (t) async {
      await boot(t, classTeacher: false);
      expect(find.byKey(const Key('leaves_not_allowed')), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('pending list with counts on the tabs; switching tabs loads that status', (t) async {
      await boot(t, data: all);
      expect(find.text('Pending (2)'), findsOneWidget);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(find.text('Omar Siddiqui'), findsOneWidget);
      expect(find.textContaining('Fever'), findsWidgets);
      expect(find.text('Requested by Mrs Malik'), findsWidgets);
      await t.tap(find.textContaining('Approved'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.text('Approved (1)'), findsOneWidget);
      await t.tap(find.textContaining('Rejected'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.text('No rejected requests'), findsOneWidget);
    });

    testWidgets('403 / 404 / error + retry / loading', (t) async {
      await boot(t, error: err(403, 'Only class teachers can review student leave requests.'));
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      Get.reset();
      await boot(t, error: err(404));
      expect(find.byKey(const Key('screen_unavailable')), findsOneWidget);
      Get.reset();
      final c = await boot(t, error: err(500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.leaves = (s, l) async => [leaveReq('p1')];
      await t.tap(find.text('Try again'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.text('Zara Malik'), findsOneWidget);
      expect(c.countOf(LeaveStatus.pending), 1);
    });

    testWidgets('detail -> Approve opens the confirm sheet with remarks; confirming updates the request and tells the teacher the parent is notified', (t) async {
      String? remarks;
      repo.review = (id, s, r) async {
        remarks = r;
        return leaveReq(id, status: s.wire, by: 'Tess Teacher', note: r, decided: DateTime.utc(2026, 10, 8));
      };
      await boot(t, data: all, screen: const StudentLeaveDetailScreen(leaveId: 'p1'));
      expect(find.byKey(const Key('leave_detail')), findsOneWidget);
      expect(find.text('Fever'), findsOneWidget);
      await t.tap(find.byKey(const Key('leave_approve')));
      await settle(t);
      expect(find.byKey(const Key('review_title')), findsOneWidget);
      expect(find.text('Approve this leave request?'), findsOneWidget);
      await t.enterText(find.byKey(const Key('review_remarks')), 'Get well soon');
      await t.tap(find.byKey(const Key('review_confirm')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(remarks, 'Get well soon');
      expect(find.byKey(const Key('leave_decided')), findsOneWidget);
      expect(find.byKey(const Key('leave_approve')), findsNothing);
      expect(find.textContaining('The parent has been notified'), findsOneWidget);
    });

    testWidgets('Cancel in the sheet sends nothing', (t) async {
      await boot(t, data: all, screen: const StudentLeaveDetailScreen(leaveId: 'p1'));
      await t.tap(find.byKey(const Key('leave_reject')));
      await settle(t);
      expect(find.text('Reject this leave request?'), findsOneWidget);
      await t.tap(find.byKey(const Key('review_cancel')));
      await settle(t);
      expect(repo.calls.where((x) => x.startsWith('review')), isEmpty);
      expect(find.byKey(const Key('leave_approve')), findsOneWidget);
    });

    testWidgets('409 already decided: the sheet closes and the screen says who decided and when', (t) async {
      var decided = false;
      repo.review = (id, s, r) async {
        decided = true;
        return fail7(409, 'This request was already approved.');
      };
      await boot(t, data: all, screen: const StudentLeaveDetailScreen(leaveId: 'p1'));
      repo.leaves = (s, l) async => decided
          ? (s == LeaveStatus.approved ? [leaveReq('p1', status: 'approved', by: 'Clara Classteacher', decided: DateTime.utc(2026, 10, 8, 7, 30))] : [])
          : (all[s] ?? []);
      await t.tap(find.byKey(const Key('leave_reject')));
      await settle(t);
      await t.tap(find.byKey(const Key('review_confirm')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.byKey(const Key('review_title')), findsNothing);
      expect(find.byKey(const Key('leave_conflict')), findsOneWidget);
      expect(find.textContaining('This request was already approved.'), findsWidgets);
      expect(find.textContaining('by Clara Classteacher'), findsWidgets);
      expect(find.byKey(const Key('leave_approve')), findsNothing);
    });

    testWidgets('403 in the sheet shows the server text and keeps the sheet open', (t) async {
      repo.review = (id, s, r) async => fail7(403, 'This student is not in your class.');
      await boot(t, data: all, screen: const StudentLeaveDetailScreen(leaveId: 'p1'));
      await t.tap(find.byKey(const Key('leave_approve')));
      await settle(t);
      await t.tap(find.byKey(const Key('review_confirm')));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.byKey(const Key('review_error')), findsOneWidget);
      expect(find.textContaining('This student is not in your class.'), findsWidgets);
      expect(find.byKey(const Key('review_title')), findsOneWidget);
    });

    testWidgets('unknown id -> "Request not found"', (t) async {
      await boot(t, data: all, screen: const StudentLeaveDetailScreen(leaveId: 'nope'));
      await t.runAsync(() => pumpEventQueueSafe());
      await settle(t);
      expect(find.byKey(const Key('leave_not_found')), findsOneWidget);
    });
  });
}

Future<void> pumpEventQueueSafe() => Future<void>.delayed(const Duration(milliseconds: 30));
