import 'package:get/get.dart';
import '../../../../core/models/messaging/notification_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/utils/notification_target.dart';
import '../../../common/action_failure.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_badges_controller.dart';
import '../../home/models/section_state.dart';

class NotificationGroup {
  final String heading;
  final List<AppNotification> items;
  const NotificationGroup(this.heading, this.items);
}

/// The notifications inbox (`/notifications`, opened by the bell).
///
/// Paging: `GET /staff-portal/notifications?limit=30[&before=<cursor>][&unread=true]`, newest first; `nextCursor` (the `createdAt` of the last
/// row, null at the end) is passed back as `before`. Read state: `POST .../:id/read` and `POST .../read-all`, applied OPTIMISTICALLY (list,
/// unread count and the bell badge change at once; a failed call rolls them back and says so). The bell badge normally comes from the
/// 60 s `unread-count` poll of [HomeBadgesController]; this screen also pushes the exact `unreadCount` of every page into it.
class NotificationsController extends GetxController {
  static const int pageSize = 30;

  final MessagingRepository? _repo;
  final HomeBadgesController? _badges;
  final AuthController? _auth;
  final Clock clock;

  NotificationsController({MessagingRepository? repository, HomeBadgesController? badges, AuthController? auth, Clock? clock})
      : _repo = repository,
        _badges = badges,
        _auth = auth,
        clock = clock ?? DateTime.now;

  MessagingRepository get repo => _repo ?? Get.find<MessagingRepository>();
  HomeBadgesController? get badges => _badges ?? (Get.isRegistered<HomeBadgesController>() ? Get.find<HomeBadgesController>() : null);
  AuthController get auth => _auth ?? Get.find<AuthController>();

  final state = Rx<SectionState<List<AppNotification>>>(const SectionState.loading());
  final unreadOnly = false.obs;
  final unreadCount = Rxn<int>();
  final loadingMore = false.obs;
  final moreFailed = false.obs;
  final markingAll = false.obs;
  final actionFailure = Rxn<ActionFailure>();

  /// A pull-to-refresh that failed while a list was on screen (the list stays; the view shows this once).
  final refreshError = RxnString();

  String? _cursor;
  int _token = 0;

  bool get hasMore => _cursor != null;
  List<AppNotification> get items => state.value.data ?? const [];

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_token;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    refreshError.value = null;
    moreFailed.value = false;
    try {
      final page = await repo.fetchNotifications(limit: pageSize, unreadOnly: unreadOnly.value);
      if (token != _token) return;
      _cursor = page.nextCursor;
      state.value = page.items.isEmpty ? const SectionState.empty() : SectionState.data(page.items);
      _takeCount(page.unreadCount);
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<List<AppNotification>>.fromError(e);
      if (previous.hasData && failed.status == SectionStatus.error) {
        state.value = previous;
        refreshError.value = failed.message;
      } else {
        state.value = failed;
      }
    }
  }

  Future<void> reload() => load(userInitiated: true);

  Future<void> setUnreadOnly(bool v) async {
    if (unreadOnly.value == v) return;
    unreadOnly.value = v;
    _cursor = null;
    state.value = const SectionState.loading();
    await load();
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || loadingMore.value || !state.value.hasData) return;
    loadingMore.value = true;
    moreFailed.value = false;
    final token = _token;
    try {
      final page = await repo.fetchNotifications(before: cursor, limit: pageSize, unreadOnly: unreadOnly.value);
      if (token != _token) return;
      final have = {for (final n in items) n.id};
      // `before` is strictly older (SPS:179) but several rows can share a millisecond: never show the same id twice.
      state.value = SectionState.data([...items, ...page.items.where((n) => !have.contains(n.id))]);
      // A page that returns the same cursor again would loop forever: stop instead.
      _cursor = page.nextCursor == cursor ? null : page.nextCursor;
      _takeCount(page.unreadCount);
    } catch (_) {
      if (token == _token) moreFailed.value = true;
    } finally {
      loadingMore.value = false;
    }
  }

  void _takeCount(int? n) {
    if (n == null) return;
    unreadCount.value = n;
    badges?.setNotificationUnread(n);
  }

  /// Notifications grouped by LOCAL calendar day, in list order (newest first).
  List<NotificationGroup> get groups {
    final now = clock();
    final out = <NotificationGroup>[];
    String? lastKey;
    for (final n in items) {
      final at = n.createdAt;
      final key = at == null ? 'unknown' : dayKey(at);
      if (key != lastKey) {
        out.add(NotificationGroup(at == null ? 'Earlier' : dayHeading(now, at), []));
        lastKey = key;
      }
      out.last.items.add(n);
    }
    return out;
  }

  /// A tap: marks it read (optimistic) and returns where to go (null = stay here). Never throws.
  NotificationTarget? tap(AppNotification n) {
    if (!n.isRead) markRead(n.id);
    return notificationTargetFor(n, isClassTeacher: auth.isClassTeacher);
  }

  Future<void> markRead(String id) async {
    final i = items.indexWhere((n) => n.id == id);
    if (i < 0 || items[i].isRead) return;
    _token++; // a refresh that started earlier carries the old read state: its answer must not undo this tap
    final before = items;
    final countBefore = unreadCount.value;
    _setItems([...before]..[i] = before[i].asRead());
    if (countBefore != null) _takeCount(countBefore > 0 ? countBefore - 1 : 0);
    try {
      await repo.markNotificationRead(id);
    } catch (e) {
      // 404 'Notification not found' (it was deleted meanwhile): nothing to roll back to.
      final gone = e is ApiException && e.statusCode == 404;
      if (gone) return;
      final cur = items;
      final j = cur.indexWhere((n) => n.id == id);
      if (j >= 0 && state.value.hasData) {
        _setItems([...cur]..[j] = before[i]);
        if (countBefore != null) _takeCount(countBefore);
      }
      actionFailure.value = ActionFailure.from(e, what: 'mark this notification as read', keep: '');
    }
  }

  /// Marks everything read. Returns true on success; on failure the list and counts are restored.
  Future<bool> markAllRead() async {
    if (markingAll.value || items.every((n) => n.isRead) && (unreadCount.value ?? 0) == 0) return false;
    markingAll.value = true;
    actionFailure.value = null;
    _token++; // an in-flight refresh/page was requested before this and would bring the unread state back (seen on the device)
    final before = items;
    final countBefore = unreadCount.value;
    if (state.value.hasData) _setItems([for (final n in before) n.asRead()]);
    _takeCount(0);
    try {
      await repo.markAllNotificationsRead();
      return true;
    } catch (e) {
      if (state.value.hasData) _setItems(before);
      if (countBefore != null) _takeCount(countBefore);
      actionFailure.value = ActionFailure.from(e, what: 'mark everything as read', keep: '');
      return false;
    } finally {
      markingAll.value = false;
    }
  }

  void _setItems(List<AppNotification> next) => state.value = SectionState.data(next);
}
