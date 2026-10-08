import 'package:get/get.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../../core/utils/home_time.dart';
import '../../../routes/app_routes.dart';
import '../../home/controllers/home_badges_controller.dart';
import '../../home/models/section_state.dart';

enum InboxFilter { open, closed }

/// The Messages inbox (tab + `/messages`).
///
/// OPEN threads are NOT fetched here: [HomeBadgesController] already polls `GET /staff-portal/threads?status=open` every 60 s while the
/// app is in the foreground (for the tab badge and the Home card), and this controller shows that same state - so the inbox adds no second
/// timer and no second request, and badge and list can never disagree. CLOSED threads are fetched on demand (`status=closed`) when that filter
/// is chosen, on pull-to-refresh and after the teacher closes a thread.
class MessagesController extends GetxController {
  final MessagingRepository? _repo;
  final HomeBadgesController? _badges;
  final Clock clock;

  MessagesController({MessagingRepository? repository, HomeBadgesController? badges, Clock? clock})
      : _repo = repository,
        _badges = badges,
        clock = clock ?? DateTime.now;

  MessagingRepository get repo => _repo ?? Get.find<MessagingRepository>();
  HomeBadgesController get badges => _badges ?? Get.find<HomeBadgesController>();

  final filter = InboxFilter.open.obs;
  final closed = Rx<SectionState<ThreadsResult>>(const SectionState.loading());
  bool _closedStale = true;
  int _closedToken = 0;

  /// The list state of the current filter.
  SectionState<ThreadsResult> get state => filter.value == InboxFilter.open ? badges.threads.value : closed.value;

  /// Rows to draw for the current filter (the server already filters; the closed/open split is re-applied defensively).
  List<MessageThread> get rows {
    final items = state.data?.items ?? const <MessageThread>[];
    return filter.value == InboxFilter.open ? items.where((t) => !t.isClosed).toList() : items.where((t) => t.isClosed).toList();
  }

  bool get mayBeCut => (state.data?.items.length ?? 0) >= ThreadsResult.serverLimit;

  void selectFilter(InboxFilter f) {
    if (f == filter.value) return;
    filter.value = f;
    if (f == InboxFilter.closed && (_closedStale || !closed.value.hasData)) loadClosed();
  }

  /// A thread was closed from the chat: the closed list must be re-read next time it is shown.
  void markClosedStale() => _closedStale = true;

  Future<void> loadClosed({bool userInitiated = false}) async {
    final token = ++_closedToken;
    final previous = closed.value;
    if (!previous.hasData) closed.value = const SectionState.loading();
    try {
      final r = await repo.fetchThreads(status: 'closed');
      if (token != _closedToken) return;
      _closedStale = false;
      closed.value = SectionState.data(r);
    } catch (e) {
      if (token != _closedToken) return;
      final failed = SectionState<ThreadsResult>.fromError(e);
      closed.value = previous.hasData && !userInitiated ? previous : failed;
    }
  }

  Future<void> reload() async {
    if (filter.value == InboxFilter.open) {
      await badges.refreshAll(userInitiated: true);
    } else {
      await loadClosed(userInitiated: true);
    }
  }

  Future<void> retry() => reload();

  /// Opens the conversation. The chat itself marks it read.
  Future<void> open(MessageThread t) async {
    await Get.toNamed(Routes.messageThreadOf(t.id));
  }

  Future<void> startNew() async {
    await Get.toNamed(Routes.messageNew);
  }
}
