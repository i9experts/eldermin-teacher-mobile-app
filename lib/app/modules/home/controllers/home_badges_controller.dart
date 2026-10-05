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

  HomeBadgesController({
    HomeRepository? repository,
    AuthController? auth,
    this.pollInterval = const Duration(seconds: 60),
    this.autoPoll = true,
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
    final f = Future.wait([refreshNotifications(), refreshThreads(userInitiated: userInitiated)])
        .then((_) {});
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

  int _threadsToken = 0;

  Future<void> refreshThreads({bool userInitiated = false}) async {
    final token = ++_threadsToken;
    final previous = threads.value;
    if (!previous.hasData) threads.value = const SectionState.loading();
    try {
      final r = await repo.fetchOpenThreads();
      if (token != _threadsToken) return;
      threads.value = SectionState.data(r);
    } catch (e) {
      if (token != _threadsToken) return;
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
