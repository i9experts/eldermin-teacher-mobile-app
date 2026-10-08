// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/chat_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/messages_controller.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/messaging/chat_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';
import '../support/fake_messaging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMessagingRepository repo;
  late FakeHomeRepository home;
  late HomeBadgesController badges;
  late FakePoller poller;
  final now = DateTime.utc(2026, 10, 5, 9);

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    repo = FakeMessagingRepository();
    home = FakeHomeRepository();
    poller = FakePoller();
    final h = await signedIn(classTeacher: true);
    badges = HomeBadgesController(repository: home, auth: h.auth, autoPoll: false);
    home.threads = () async => ThreadsResult(items: [thread('t1', unread: true), thread('t2', unread: true, guardian: 'Mr Ali')]);
    await badges.refreshThreads();
  });
  tearDown(Get.reset);

  ChatController make({String id = 't1'}) => ChatController(
        threadId: id,
        repository: repo,
        badges: badges,
        clock: () => now,
        observeLifecycle: false,
        timerFactory: poller.create,
      );

  Future<ChatController> opened({bool unread = true, List<ChatMessage>? msgs}) async {
    repo.messages = (id) async => ThreadMessages(
        thread: thread(id, unread: unread),
        messages: msgs ?? [serverMsg('m1', 'Hello ma\'am'), serverMsg('m2', 'Sure', mine: true)]);
    final c = make();
    await c.loadThread();
    await pumpEventQueue();
    return c;
  }

  group('load and mark read', () {
    test('messages come oldest first, mine are marked, the thread header is kept', () async {
      final c = await opened();
      expect(c.load.value.status, SectionStatus.data);
      expect(c.messages.map((m) => m.id), ['m1', 'm2']);
      expect(c.messages.map((m) => m.fromMe), [false, true]);
      expect(c.thread!.guardianName, 'Mrs Malik');
    });

    test('an unread thread is marked read on open and the inbox/tab badge follow at once', () async {
      expect(badges.messagesUnread, 2);
      final c = await opened();
      expect(repo.calls, contains('read:t1'));
      expect(c.thread!.staffHasUnread, isFalse);
      expect(badges.messagesUnread, 1);
      expect(badges.threads.value.data!.items.firstWhere((t) => t.id == 't1').staffHasUnread, isFalse);
    });

    test('an already read thread is not marked again', () async {
      await opened(unread: false);
      expect(repo.calls.where((c) => c.startsWith('read:')), isEmpty);
    });

    test('a failed mark-read is silent and retried on the next poll while still unread', () async {
      var fails = true;
      repo.read = (_) async => fails ? fail7(500) : null;
      final c = await opened();
      expect(c.load.value.status, SectionStatus.data);
      expect(badges.messagesUnread, 2, reason: 'not cleared when the server call failed');
      fails = false;
      poller.fire();
      await pumpEventQueue();
      expect(repo.calls.where((x) => x == 'read:t1'), hasLength(2));
      expect(badges.messagesUnread, 1);
    });

    test('load failures map to states: not found vs not deployed vs forbidden vs wrong shape', () async {
      repo.messages = (_) async => fail7(404, 'Thread not found');
      var c = make();
      await c.loadThread();
      expect(c.notFound.value, isTrue);
      expect(c.load.value.status, SectionStatus.empty);

      repo.messages = (_) async => fail7(404, 'Cannot GET /api/v1/staff-portal/threads/t1/messages');
      c = make();
      await c.loadThread();
      expect(c.notFound.value, isFalse);
      expect(c.load.value.status, SectionStatus.unavailable);

      repo.messages = (_) async => fail7(403, 'Forbidden resource');
      c = make();
      await c.loadThread();
      expect(c.load.value.status, SectionStatus.forbidden);

      repo.messages = (_) async => fail7(500);
      c = make();
      await c.loadThread();
      expect(c.load.value.status, SectionStatus.error);
      expect(c.isPolling, isFalse, reason: 'no polling without a loaded thread');
    });

    test('a thread that comes back closed has a read-only composer', () async {
      repo.messages = (id) async => ThreadMessages(thread: thread(id, status: 'closed'), messages: [serverMsg('m1', 'Bye')]);
      final c = make();
      await c.loadThread();
      expect(c.closed.value, isTrue);
      expect(c.canCompose, isFalse);
      expect(c.submit(), isFalse);
      expect(c.isPolling, isFalse);
    });

    test('a thread at the server limit of 500 (the newest 500) is flagged: earlier ones are not shown', () async {
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [for (var i = 0; i < 500; i++) serverMsg('m$i', 'x')]);
      final c = make();
      await c.loadThread();
      expect(c.truncated.value, isTrue);
    });
  });

  group('send', () {
    test('optimistic: visible as sending at once, the composer is cleared, success swaps in the server message (no duplicate)', () async {
      final gate = Completer<ChatMessage>();
      repo.send = (id, body) => gate.future;
      final c = await opened(unread: false);
      c.composer.text = '  Please bring the form  ';
      expect(c.submit(), isTrue);
      expect(c.composer.text, isEmpty);
      expect(c.messages.last.state, SendState.sending);
      expect(c.messages.last.body, 'Please bring the form', reason: 'trimmed like the server does');
      gate.complete(serverMsg('m3', 'Please bring the form', mine: true));
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(c.messages.every((m) => m.state == SendState.sent), isTrue);
      final row = badges.threads.value.data!.items.firstWhere((t) => t.id == 't1');
      expect(row.lastMessagePreview, 'Please bring the form');
    });

    test('a double tap sends once (the first tap empties the composer)', () async {
      final c = await opened(unread: false);
      c.composer.text = 'Hello';
      c.submit();
      c.submit();
      await pumpEventQueue();
      expect(repo.sentBodies, ['Hello']);
    });

    test('empty, blank and over-long text is refused before any request', () async {
      final c = await opened(unread: false);
      expect(c.send(''), isFalse);
      expect(c.send('   '), isFalse);
      expect(c.send('x' * 4001), isFalse);
      expect(c.validate('x' * 4001), contains('4000'));
      expect(c.send('x' * 4000), isTrue);
      await pumpEventQueue();
      expect(repo.sentBodies, hasLength(1));
    });

    test('a failed send stays visible as failed and Retry sends it (once, never two in flight)', () async {
      var attempts = 0;
      final gate = Completer<ChatMessage>();
      repo.send = (id, body) {
        attempts++;
        if (attempts == 1) fail7(503);
        return gate.future;
      };
      final c = await opened(unread: false);
      c.send('Hello');
      await pumpEventQueue();
      final failed = c.messages.last;
      expect(failed.state, SendState.failed);
      expect(failed.canRetry, isTrue);
      expect(c.messages.where((m) => m.body == 'Hello'), hasLength(1));
      expect(c.retry(failed.clientId), isTrue);
      expect(c.retry(failed.clientId), isFalse, reason: 'already sending: a second tap is ignored');
      await pumpEventQueue();
      expect(attempts, 2);
      gate.complete(serverMsg('m9', 'Hello', mine: true));
      await pumpEventQueue();
      expect(c.messages.where((m) => m.body == 'Hello'), hasLength(1));
      expect(c.messages.last.id, 'm9');
      expect(c.pendingCount, 0);
    });

    test('offline failure keeps the text and offers Retry', () async {
      repo.send = (id, body) => fail7(null, "You're offline");
      final c = await opened(unread: false);
      c.send('Hello');
      await pumpEventQueue();
      expect(c.messages.last.state, SendState.failed);
      expect(c.messages.last.canRetry, isTrue);
      expect(c.messages.last.failureText, 'No connection.');
    });

    test('409 closed: the message fails WITHOUT retry, the thread becomes read-only and leaves the open inbox list', () async {
      repo.send = (id, body) => fail7(409, 'This conversation is closed.');
      final c = await opened(unread: false);
      c.send('Hello');
      await pumpEventQueue();
      final m = c.messages.last;
      expect(m.state, SendState.failed);
      expect(m.canRetry, isFalse);
      expect(m.failureText, 'This conversation is closed.');
      expect(c.closed.value, isTrue);
      expect(c.canCompose, isFalse);
      expect(c.retry(m.clientId), isFalse);
      expect(c.isPolling, isFalse);
      expect(badges.threads.value.data!.items.any((t) => t.id == 't1'), isFalse);
      c.discard(m.clientId);
      expect(c.messages.any((x) => x.clientId == m.clientId), isFalse);
    });

    test('400 validation shows the server text and offers no retry', () async {
      repo.send = (id, body) => fail7(400, 'body must be shorter than or equal to 4000 characters');
      final c = await opened(unread: false);
      c.send('Hello');
      await pumpEventQueue();
      expect(c.messages.last.failureText, 'body must be shorter than or equal to 4000 characters');
      expect(c.messages.last.canRetry, isFalse);
      expect(c.closed.value, isFalse);
    });

    test('messages are sent one after another, in order', () async {
      final gates = [Completer<ChatMessage>(), Completer<ChatMessage>()];
      var i = 0;
      repo.send = (id, body) => gates[i++].future;
      final c = await opened(unread: false);
      c.send('first');
      c.send('second');
      await pumpEventQueue();
      expect(repo.sentBodies, ['first'], reason: 'the second waits for the first');
      gates[0].complete(serverMsg('m3', 'first', mine: true));
      await pumpEventQueue();
      expect(repo.sentBodies, ['first', 'second']);
      gates[1].complete(serverMsg('m4', 'second', mine: true));
      await pumpEventQueue();
      expect(c.messages.map((m) => m.body).toList().sublist(2), ['first', 'second']);
    });
  });

  group('polling', () {
    test('starts after the first load at the 10 s cadence; a tick re-reads and appends new messages without touching the composer or a pending send', () async {
      final c = await opened(unread: false);
      expect(poller.created, [const Duration(seconds: 10)]);
      expect(c.isPolling, isTrue);
      c.composer.text = 'half-typed';
      final gate = Completer<ChatMessage>();
      repo.send = (id, body) => gate.future;
      c.send('pending one');
      await pumpEventQueue();
      expect(c.messages.last.state, SendState.sending);
      // the guardian wrote meanwhile; a poll during an in-flight send is skipped (its answer would race the send)
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'Hello ma\'am'), serverMsg('m2', 'Sure', mine: true), serverMsg('m5', 'One more thing')]);
      final calls = repo.calls.where((x) => x.startsWith('messages:')).length;
      poller.fire();
      await pumpEventQueue();
      expect(repo.calls.where((x) => x.startsWith('messages:')).length, calls, reason: 'skipped while sending');
      gate.complete(serverMsg('m6', 'pending one', mine: true));
      await pumpEventQueue();
      poller.fire();
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id).toSet(), {'m1', 'm2', 'm5', 'm6'}, reason: 'merged by _id: nothing lost, the sent message kept');
      expect(c.messages, hasLength(4));
      expect(c.newIncoming.value, 1);
      expect(c.composer.text, 'half-typed');
    });

    test('a poll keeps a failed local message after the server messages', () async {
      repo.send = (id, body) => fail7(503);
      final c = await opened(unread: false);
      c.send('stuck');
      await pumpEventQueue();
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m7', 'b', at: DateTime.utc(2026, 10, 5, 8, 5))]);
      poller.fire();
      await pumpEventQueue();
      expect(c.messages.map((m) => m.body), ['Hello ma\'am', 'Sure', 'b', 'stuck']);
      expect(c.messages.last.state, SendState.failed);
    });

    test('a poll asks only for messages after the newest createdAt it holds and appends them in order', () async {
      final t0 = DateTime.utc(2026, 10, 5, 8), t1 = DateTime.utc(2026, 10, 5, 8, 30);
      final c = await opened(unread: false, msgs: [serverMsg('m1', 'a', at: t0), serverMsg('m2', 'b', mine: true, at: t1)]);
      expect(repo.afters, [null], reason: 'the initial load has no after');
      repo.messagesAfter = (id, after) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m3', 'c', at: DateTime.utc(2026, 10, 5, 9))]);
      poller.fire();
      await pumpEventQueue();
      expect(repo.afters.last, t1);
      expect(c.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(c.newIncoming.value, 1);
      // an empty answer changes nothing
      repo.messagesAfter = (id, after) async => ThreadMessages(thread: thread(id), messages: const []);
      poller.fire();
      await pumpEventQueue();
      expect(repo.afters.last, DateTime.utc(2026, 10, 5, 9));
      expect(c.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    });

    test('a server that ignores after (older deployment) answers the whole thread: merged by _id, no duplicates, no new-message count for known ones', () async {
      final t0 = DateTime.utc(2026, 10, 5, 8), t1 = DateTime.utc(2026, 10, 5, 8, 30);
      final c = await opened(unread: false, msgs: [serverMsg('m1', 'a', at: t0), serverMsg('m2', 'b', at: t1)]);
      final before = c.messages.toList();
      repo.messagesAfter = (id, after) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'a', at: t0), serverMsg('m2', 'b', at: t1)]);
      poller.fire();
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id), ['m1', 'm2']);
      expect(identical(c.messages[0], before[0]), isTrue, reason: 'known rows are left alone (no flicker)');
      expect(c.newIncoming.value, 0);
      repo.messagesAfter = (id, after) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'a', at: t0), serverMsg('m2', 'b', at: t1), serverMsg('m3', 'c', at: DateTime.utc(2026, 10, 5, 9))]);
      poller.fire();
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(c.newIncoming.value, 1);
    });

    test('a failing poll keeps the messages on screen and flags it; the next good poll clears the flag', () async {
      final c = await opened(unread: false);
      repo.messages = (_) async => fail7(500);
      poller.fire();
      await pumpEventQueue();
      expect(c.pollFailing.value, isTrue);
      expect(c.messages, hasLength(2));
      expect(c.load.value.status, SectionStatus.data);
      repo.messages = (id) async => ThreadMessages(thread: thread(id), messages: [serverMsg('m1', 'a')]);
      poller.fire();
      await pumpEventQueue();
      expect(c.pollFailing.value, isFalse);
    });

    test('a new guardian message makes the thread unread again and the chat marks it read while open', () async {
      final c = await opened(unread: false);
      repo.messages = (id) async => ThreadMessages(thread: thread(id, unread: true), messages: [serverMsg('m1', 'a'), serverMsg('m8', 'new!')]);
      poller.fire();
      await pumpEventQueue();
      expect(repo.calls, contains('read:t1'));
      expect(c.newIncoming.value, 1);
      c.clearNewIncoming();
      expect(c.newIncoming.value, 0);
    });

    test('app lifecycle: paused stops the timer, resumed polls at once and restarts it', () async {
      final c = await opened(unread: false);
      expect(poller.active, isTrue);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(c.isPolling, isFalse);
      expect(poller.active, isFalse);
      final before = repo.calls.where((x) => x.startsWith('messages:')).length;
      poller.fire();
      await pumpEventQueue();
      expect(repo.calls.where((x) => x.startsWith('messages:')).length, before, reason: 'a stopped timer never polls');
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(repo.calls.where((x) => x.startsWith('messages:')).length, before + 1);
      expect(c.isPolling, isTrue);
      expect(poller.created, hasLength(2));
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(c.isPolling, isFalse);
    });

    test('closing the screen (onClose) stops polling', () async {
      final c = await opened(unread: false);
      c.onClose();
      expect(poller.active, isFalse);
      expect(c.isPolling, isFalse);
    });
  });

  group('close', () {
    test('closing makes the thread read-only, stops polling and removes it from the open list', () async {
      final c = await opened(unread: false);
      expect(await c.close(), isTrue);
      expect(c.closed.value, isTrue);
      expect(c.isPolling, isFalse);
      expect(badges.threads.value.data!.items.any((t) => t.id == 't1'), isFalse);
      expect(badges.messagesUnread, 1, reason: 'only t2 is left unread');
    });

    test('a failed close keeps it open and reports why; a second tap while closing is ignored', () async {
      final gate = Completer<MessageThread>();
      repo.close = (id) => gate.future;
      final c = await opened(unread: false);
      final first = c.close();
      expect(await c.close(), isFalse);
      gate.completeError(ApiException('boom', statusCode: 500));
      expect(await first, isFalse);
      expect(c.closed.value, isFalse);
      expect(c.closeFailure.value, isNotNull);
      expect(c.canCompose, isTrue);
    });

    test('closing marks the closed inbox list stale', () async {
      final inbox = Get.put(MessagesController(repository: repo, badges: badges));
      final c = await opened(unread: false);
      var loads = 0;
      repo.threads = (s) async {
        loads++;
        return ThreadsResult(items: [thread('t1', status: 'closed')]);
      };
      inbox.selectFilter(InboxFilter.closed);
      await pumpEventQueue();
      expect(loads, 1);
      inbox.selectFilter(InboxFilter.open);
      inbox.selectFilter(InboxFilter.closed);
      await pumpEventQueue();
      expect(loads, 1, reason: 'not stale: no refetch');
      await c.close();
      inbox.selectFilter(InboxFilter.open);
      inbox.selectFilter(InboxFilter.closed);
      await pumpEventQueue();
      expect(loads, 2);
    });
  });
}

