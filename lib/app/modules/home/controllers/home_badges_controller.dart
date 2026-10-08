import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/home_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/section_state.dart';

/// Unread badges for the shell: notification bell + Messages tab, and the
/// threads list the dashboard's Messages section reads.
///
/// Both endpoints are NEW on feat/staff-portal and not deployed to
/// production yet: a 404/501 means "feature not available yet" -> no badge,
/// never a crash and never an invented count.
///
/// Polls every [pollInterval] (60 s) while the app is in the foreground and
/// refreshes immediately on resume; the timer is stopped in the background.
class HomeBadgesController extends GetxController with WidgetsBindingObserver {
  final HomeRepository? _repo;
  final AuthController? _auth;
  final Duration pollInterval;
  final bool autoPoll;

  /// A refresh that has not finished after this long is abandoned: the next poll / pull starts a FRESH request instead of joining a hung one.
  final Duration refreshDeadline;

  HomeBadgesController({
    HomeRepository? repository,
    AuthController? auth,
    this.pollInterval = const Duration(seconds: 60),
    this.autoPoll = true,
    this.refreshDeadline = const Duration(seconds: 20),
  })  : _repo = repository,
        _auth = auth;

  HomeRepository get repo => _repo ?? Get.find<HomeRepository>();
  AuthController get auth => _auth ?? Get.find<AuthController>();

  /// null = no badge (unavailable, unknown or zero is rendered as no badge by the view).
  final notificationUnread = Rxn<int>();
  final notificationsUnavailable = false.obs;
  final threads = Rx<SectionState<ThreadsResult>>(const SectionState.loading());

  Timer? _timer;

  /// Unread threads for the Messages tab (null when unknown/unavailable).
  int? get messagesUnread {
    final t = threads.value;
    return t.hasData ? t.data!.unreadCount : null;
  }

  bool get messagesUnreadCapped => threads.value.data?.mayUndercount ?? false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    if (autoPoll) {
      refreshAll();
      _startTimer();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!autoPoll) return;
    if (state == AppLifecycleState.resumed) {
      refreshAll();
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(pollInterval, (_) => refreshAll());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool get _signedIn => auth.status.value == AuthStatus.authenticated;

  /// Refreshes both badges. [userInitiated] (pull-to-refresh / retry) makes a
  /// failure visible in the Messages section; a silent poll keeps the last
  /// real data instead of flashing an error.
  Future<void> refreshAll({bool userInitiated = false}) async {
    if (!_signedIn) return;
    // Startup calls from the shell and the dashboard share one request.
    final running = _inFlight;
    if (running != null && !userInitiated) return running;
    final f = Future.wait<void>([refreshNotifications(), refreshThreads(userInitiated: userInitiated)]).timeout(refreshDeadline, onTimeout: () {
      expireThreads('The server is taking too long to answer. Please try again.', onlyIfNoData: !userInitiated);
      return <void>[];
    }).then((_) {});
    _inFlight = f;
    try {
      await f;
    } finally {
      if (identical(_inFlight, f)) _inFlight = null;
    }
  }

  Future<void>? _inFlight;

  Future<void> refreshNotifications() async {
    try {
      final n = await repo.fetchNotificationUnreadCount();
      notificationsUnavailable.value = false;
      notificationUnread.value = n;
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501 || e.statusCode == 403) {
        notificationsUnavailable.value = true;
        notificationUnread.value = null;
      }
      // Offline / 5xx: keep the last real count.
    } catch (_) {}
  }

  // ── Local sync (Messages tab / Home card stay consistent with what the teacher just did, without waiting for the next poll) ──

  /// Applies [change] to the open-thread list row [id] (e.g. unread cleared after opening it, a fresh preview after sending).
  /// A closed result leaves the open list; an unknown id is ignored. Never invents data: it only edits rows the server sent.
  void applyThreadChange(String id, MessageThread Function(MessageThread) change) {
    final cur = threads.value.data;
    if (cur == null || !threads.value.hasData) return;
    final next = <MessageThread>[];
    for (final t in cur.items) {
      if (t.id != id) {
        next.add(t);
        continue;
      }
      final c = change(t);
      if (!c.isClosed) next.add(c);
    }
    threads.value = SectionState.data(cur.withItems(next));
  }

  /// A thread the teacher just started goes to the top of the open list (the server sorts by lastMessageAt desc).
  void addOpenThread(MessageThread t) {
    final cur = threads.value.data;
    if (cur == null || !threads.value.hasData) return;
    threads.value = SectionState.data(cur.withItems([t, ...cur.items.where((x) => x.id != t.id)]));
  }

  /// Bell badge set from a fresh server count (notifications inbox) or a local read/read-all.
  void setNotificationUnread(int n) {
    notificationsUnavailable.value = false;
    notificationUnread.value = n < 0 ? 0 : n;
  }

  int _threadsToken = 0;

  /// Ends a pending threads load in an error state and makes any late answer irrelevant. A silent poll ([onlyIfNoData]) keeps real data.
  void expireThreads(String message, {bool onlyIfNoData = false}) {
    final t = threads.value;
    if (onlyIfNoData && t.hasData) {
      _threadsToken++;
      return;
    }
    if (t.status != SectionStatus.loading && !_threadsPending) return;
    _threadsToken++;
    threads.value = SectionState<ThreadsResult>.error(message);
  }

  bool _threadsPending = false;

  Future<void> refreshThreads({bool userInitiated = false}) async {
    final token = ++_threadsToken;
    final previous = threads.value;
    if (!previous.hasData) threads.value = const SectionState.loading();
    _threadsPending = true;
    try {
      final r = await repo.fetchOpenThreads();
      if (token != _threadsToken) return;
      _threadsPending = false;
      threads.value = SectionState.data(r);
    } catch (e) {
      if (token != _threadsToken) return;
      _threadsPending = false;
      final failed = SectionState<ThreadsResult>.fromError(e);
      final transient = failed.status == SectionStatus.error;
      if (previous.hasData && transient && !userInitiated) {
        threads.value = previous;
      } else {
        threads.value = failed;
      }
    }
  }
}
