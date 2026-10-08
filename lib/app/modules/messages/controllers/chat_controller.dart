import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../common/action_failure.dart';
import '../../home/controllers/home_badges_controller.dart';
import '../../home/models/section_state.dart';
import 'messages_controller.dart';

/// Creates the repeating poll timer. Injected so tests drive ticks by hand (no wall-clock waiting).
typedef PollTimerFactory = Timer Function(Duration interval, void Function() tick);

Timer _periodic(Duration d, void Function() tick) => Timer.periodic(d, (_) => tick());

/// One conversation (`/messages/:threadId`).
///
/// * Load: `GET /staff-portal/threads/:id/messages` -> thread + the newest 500 messages (oldest first, backend 265fcfa). Polls ask
///   `?after=<createdAt of the newest message held>` and merge the answer by `_id` (works with a server that ignores `after`).
/// * Mark read: `POST .../read` when the thread says `staffHasUnread` (the GET does not clear it, SPS:233-237); retried on the next poll while
///   it is still unread. A failure is silent (nothing the teacher can do about it).
/// * Polling (v1 has no sockets and no push): every [pollInterval] (10 s) while the chat is open AND the app is in the foreground; stopped
///   when the app is backgrounded and when the controller is closed. A poll that fails keeps the messages on screen ([pollFailing]).
/// * Send: optimistic. The text is cleared from the composer at once, the message is shown as "sending", requests are serialised in order,
///   success swaps it for the server message (same id never appears twice), a transient failure leaves it visible as "Not sent - Retry".
///   A 409 closed / 400 / 403 answer is the server's verdict: no Retry, the teacher can remove the message.
/// * Close: `PATCH .../close` (confirmation is the view's job); the composer becomes read-only.
class ChatController extends GetxController with WidgetsBindingObserver {
  final String threadId;
  final MessagingRepository? _repo;
  final HomeBadgesController? _badges;
  final Duration pollInterval;
  final bool observeLifecycle;
  final Clock clock;
  final PollTimerFactory _timerFactory;

  ChatController({
    required this.threadId,
    MessagingRepository? repository,
    HomeBadgesController? badges,
    this.pollInterval = const Duration(seconds: 10),
    this.observeLifecycle = true,
    Clock? clock,
    PollTimerFactory? timerFactory,
  })  : _repo = repository,
        _badges = badges,
        clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? _periodic;

  MessagingRepository get repo => _repo ?? Get.find<MessagingRepository>();
  HomeBadgesController? get badges => _badges ?? (Get.isRegistered<HomeBadgesController>() ? Get.find<HomeBadgesController>() : null);

  /// The composer. Owned here so a rebuild, a poll or a failed send never loses what the teacher is typing.
  final composer = TextEditingController();

  /// Loading / error / forbidden / unavailable of the first load; data = the thread header.
  final load = Rx<SectionState<MessageThread>>(const SectionState.loading());

  /// The thread id does not exist for this staff member (404 'Thread not found', SPS:229-231), as opposed to an undeployed endpoint.
  final notFound = false.obs;

  final messages = <ChatMessage>[].obs;
  final closed = false.obs;
  final closing = false.obs;
  final closeFailure = Rxn<ActionFailure>();
  final pollFailing = false.obs;

  /// The thread reached the server's 500-message limit: EARLIER messages are not shown (the newest 500 always are).
  final truncated = false.obs;

  /// Guardian messages that arrived through polling since the view last reached the bottom (drives the "New messages" chip).
  final newIncoming = 0.obs;

  Timer? _timer;
  bool _foreground = true;
  bool _disposed = false;
  int _seq = 0;
  int _loadToken = 0;
  bool _polling = false;
  bool _markingRead = false;
  Future<void> _sendChain = Future<void>.value();
  int _inFlightSends = 0;

  bool get isPolling => _timer != null;
  MessageThread? get thread => load.value.data;

  /// The composer can send: loaded, open, nothing is wrong with the thread.
  bool get canCompose => load.value.hasData && !closed.value;

  int get pendingCount => messages.where((m) => m.state != SendState.sent).length;

  @override
  void onInit() {
    super.onInit();
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    loadThread();
  }

  @override
  void onClose() {
    _disposed = true;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    composer.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    if (fg) {
      if (load.value.hasData) {
        poll();
        _syncTimer();
      }
    } else {
      _stopTimer();
    }
  }

  void _syncTimer() {
    final should = !_disposed && _foreground && load.value.hasData && !closed.value;
    if (should && _timer == null) {
      _timer = _timerFactory(pollInterval, poll);
    } else if (!should) {
      _stopTimer();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── load / poll ──────────────────────────────────────────────

  Future<void> loadThread() async {
    final token = ++_loadToken;
    load.value = const SectionState.loading();
    notFound.value = false;
    try {
      final r = await repo.fetchThreadMessages(threadId);
      if (token != _loadToken || _disposed) return;
      _applyServer(r, initial: true);
      load.value = SectionState.data(r.thread);
      _syncTimer();
      unawaited(_markReadIfNeeded());
    } catch (e) {
      if (token != _loadToken || _disposed) return;
      if (e is ApiException && e.statusCode == 404 && !e.message.startsWith('Cannot ')) {
        notFound.value = true;
        load.value = const SectionState.empty();
      } else {
        load.value = SectionState<MessageThread>.fromError(e);
      }
    }
  }

  /// One poll. Never throws; skipped while the first load is running, while a send is in flight (its answer would race the merge) or while
  /// another poll is running.
  Future<void> poll() async {
    if (_disposed || _polling || _inFlightSends > 0 || !load.value.hasData) return;
    _polling = true;
    final token = _loadToken;
    try {
      final r = await repo.fetchThreadMessages(threadId, after: _newestKnown());
      if (token != _loadToken || _disposed || _inFlightSends > 0) return;
      pollFailing.value = false;
      _applyServer(r, initial: false);
      load.value = SectionState.data(r.thread);
      unawaited(_markReadIfNeeded());
      _syncTimer();
    } catch (_) {
      if (!_disposed) pollFailing.value = true;
    } finally {
      _polling = false;
    }
  }

  /// `createdAt` of the newest message we hold from the server (the `after` cursor of a poll); null when we hold none (then the poll asks
  /// for the whole thread, like the first load).
  DateTime? _newestKnown() {
    DateTime? newest;
    for (final m in messages) {
      final at = m.createdAt;
      if (m.id.isEmpty || at == null) continue;
      if (newest == null || at.isAfter(newest)) newest = at;
    }
    return newest;
  }

  /// Initial load: replaces the list. Poll: MERGES by `_id` (a server that ignored `after` answers the whole thread; known messages are not
  /// duplicated, replaced in place so the list does not flicker, and an unchanged list is not reassigned).
  void _applyServer(ThreadMessages r, {required bool initial}) {
    final locals = messages.where((m) => m.state != SendState.sent).toList();
    if (initial) {
      messages.assignAll([...r.messages, ...locals]);
      truncated.value = r.possiblyTruncated;
    } else {
      final sentNow = messages.where((m) => m.state == SendState.sent).toList();
      final byId = {for (final m in sentNow) if (m.id.isNotEmpty) m.id: m};
      final fresh = <ChatMessage>[];
      for (final m in r.messages) {
        if (m.id.isEmpty || byId.containsKey(m.id)) continue;
        byId[m.id] = m;
        fresh.add(m);
      }
      final incoming = fresh.where((m) => !m.fromMe).length;
      if (fresh.isNotEmpty) {
        final merged = [...sentNow, ...fresh];
        // Stable sort by createdAt (messages without a date keep their place at the end of the sent ones).
        final indexed = [for (var i = 0; i < merged.length; i++) (i, merged[i])];
        indexed.sort((a, b) {
          final x = a.$2.createdAt, y = b.$2.createdAt;
          if (x == null || y == null) return a.$1.compareTo(b.$1);
          final c = x.compareTo(y);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
        // A local message whose server twin was fetched is dropped by the send path (it swaps by id); the rest stay at the end.
        messages.assignAll([...indexed.map((e) => e.$2), ...locals]);
        newIncoming.value += incoming;
      }
    }
    closed.value = r.thread.isClosed;
  }

  Future<void> _markReadIfNeeded() async {
    final t = thread;
    if (_markingRead || t == null || !t.staffHasUnread) return;
    _markingRead = true;
    try {
      await repo.markThreadRead(threadId);
      if (_disposed) return;
      final cleared = t.copyWith(staffHasUnread: false);
      load.value = SectionState.data(cleared);
      badges?.applyThreadChange(threadId, (x) => x.copyWith(staffHasUnread: false));
    } catch (_) {
      // silent: the next poll sees the thread still unread and tries again
    } finally {
      _markingRead = false;
    }
  }

  void clearNewIncoming() {
    if (newIncoming.value != 0) newIncoming.value = 0;
  }

  // ── send ─────────────────────────────────────────────────────

  /// Validation text for the composer (null = fine). The limits are the DTO's (SendThreadMessageDto: 1..4000).
  String? validate(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Type a message first';
    if (t.length > NewThreadRequest.messageMax) return 'Messages can be at most ${NewThreadRequest.messageMax} characters';
    return null;
  }

  /// Sends what is in the composer. The composer is cleared synchronously, so a second tap in the same frame finds nothing to send
  /// (no duplicate). Returns true when a message was queued.
  bool submit() {
    final text = composer.text;
    if (!canCompose || validate(text) != null) return false;
    composer.clear();
    return send(text);
  }

  /// Queues [text] as a new optimistic message.
  bool send(String text) {
    if (!canCompose || validate(text) != null) return false;
    final body = text.trim();
    final cid = 'c${++_seq}';
    messages.add(ChatMessage(clientId: cid, body: body, fromMe: true, createdAt: clock(), state: SendState.sending));
    _enqueue(cid);
    return true;
  }

  /// Retry of a failed message. Ignored unless it is failed and retrying can help; a message already sending is never sent twice.
  bool retry(String clientId) {
    final i = messages.indexWhere((m) => m.clientId == clientId);
    if (i < 0) return false;
    final m = messages[i];
    if (m.state != SendState.failed || !m.canRetry || closed.value) return false;
    messages[i] = m.copyWith(state: SendState.sending, failureText: '');
    _enqueue(clientId);
    return true;
  }

  /// Removes a failed message the teacher gave up on.
  void discard(String clientId) {
    final i = messages.indexWhere((m) => m.clientId == clientId && m.state == SendState.failed);
    if (i >= 0) messages.removeAt(i);
  }

  void _enqueue(String cid) {
    _inFlightSends++;
    _sendChain = _sendChain.then((_) => _deliver(cid)).whenComplete(() {
      _inFlightSends--;
    });
  }

  Future<void> _deliver(String cid) async {
    var i = messages.indexWhere((m) => m.clientId == cid);
    if (i < 0 || messages[i].state != SendState.sending) return;
    final body = messages[i].body;
    try {
      final sent = await repo.sendMessage(threadId, body);
      i = messages.indexWhere((m) => m.clientId == cid);
      // Drop any copy of the server message that a fetch brought in meanwhile, then swap the local one for it.
      messages.removeWhere((m) => m.id == sent.id && m.clientId != cid);
      i = messages.indexWhere((m) => m.clientId == cid);
      if (i >= 0) {
        messages[i] = sent;
      } else if (!messages.any((m) => m.id == sent.id)) {
        messages.add(sent);
      }
      final preview = body.length > 140 ? body.substring(0, 140) : body;
      badges?.applyThreadChange(threadId, (x) => x.copyWith(staffHasUnread: false, lastMessagePreview: preview, lastMessageAt: sent.createdAt ?? clock()));
    } catch (e) {
      final f = ActionFailure.from(e, what: 'send this message', keep: 'Your message is kept.');
      i = messages.indexWhere((m) => m.clientId == cid);
      if (f.kind == ActionFailureKind.conflict) _markClosedLocally();
      if (i >= 0) {
        final text = switch (f.kind) {
          ActionFailureKind.conflict => f.serverMessage.isEmpty ? 'This conversation is closed.' : f.serverMessage,
          ActionFailureKind.validation || ActionFailureKind.forbidden => f.serverMessage.isEmpty ? f.message : f.serverMessage,
          ActionFailureKind.offline => 'No connection.',
          _ => 'Could not reach the server.',
        };
        messages[i] = messages[i].copyWith(state: SendState.failed, failureText: text, canRetry: f.canRetry);
      }
    }
  }

  void _markClosedLocally() {
    closed.value = true;
    _syncTimer();
    final t = thread;
    if (t != null) load.value = SectionState.data(t.copyWith(status: 'closed'));
    badges?.applyThreadChange(threadId, (x) => x.copyWith(status: 'closed'));
    if (Get.isRegistered<MessagesController>()) Get.find<MessagesController>().markClosedStale();
  }

  // ── close ────────────────────────────────────────────────────

  /// Closes the conversation (the caller has already confirmed). Returns true on success.
  Future<bool> close() async {
    if (closing.value || closed.value) return false;
    closing.value = true;
    closeFailure.value = null;
    try {
      await repo.closeThread(threadId);
      _markClosedLocally();
      return true;
    } catch (e) {
      closeFailure.value = ActionFailure.from(e, what: 'close this conversation', keep: '');
      return false;
    } finally {
      closing.value = false;
    }
  }
}
