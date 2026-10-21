import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/notification_models.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart' show RefreshFailedBanner;
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/controllers/home_shell_controller.dart';
import '../controllers/notifications_controller.dart';
import '../../../../core/design/design.dart';

/// Notifications inbox (`/notifications`): grouped by day, unread dot, tap = mark read + open what it is about. Infinite scroll by cursor.
class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({super.key});

  NotificationsController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(
        title: 'Notifications',
        actions: [
          Obx(() {
            final enabled = (c.unreadCount.value ?? 0) > 0 && !c.markingAll.value && c.state.value.hasData;
            return EmIconCircleButton(
              key: const Key('notif_mark_all'),
              icon: Icons.done_all_rounded,
              semanticLabel: 'Mark all read',
              tooltip: 'Mark all read',
              onTap: enabled ? () => _markAll(context) : null,
            );
          }),
        ],
      ),
      body: _List(c: c),
    );
  }

  Future<void> _markAll(BuildContext context) async {
    final ok = await c.markAllRead();
    if (!context.mounted) return;
    final f = c.actionFailure.value;
    if (!ok && f != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
  }
}

class _List extends StatefulWidget {
  final NotificationsController c;
  const _List({required this.c});
  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  final _scroll = ScrollController();
  NotificationsController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.maxScrollExtent - _scroll.position.pixels < 300) c.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unreadOnly = c.unreadOnly.value;
      final refreshError = c.refreshError.value;
      final now = c.clock();
      return ScreenStateView<List<AppNotification>>(
        state: c.state.value,
        scrollController: _scroll,
        onRefresh: c.reload,
        onRetry: c.load,
        emptyIcon: Icons.notifications_none_rounded,
        emptyTitle: unreadOnly ? 'No unread notifications' : 'No notifications yet',
        emptySubtitle: unreadOnly ? "You're all caught up." : 'Updates about messages, meetings, substitutions and leave appear here.',
        padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s24),
        header: [
          EmSegmentedTabs<bool>(key: const Key('notif_filter'), segments: const [EmSegment(false, 'All'), EmSegment(true, 'Unread')], selected: unreadOnly, onChanged: c.setUnreadOnly),
          const SizedBox(height: EmSpacing.s16),
          if (refreshError != null) RefreshFailedBanner(key: const Key('notif_refresh_error'), message: refreshError, onRetry: c.reload),
        ],
        builder: (_) => [
          for (final g in c.groups) ...[
            Padding(padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8), child: Text(g.heading, style: EmType.label.copyWith(color: EmColors.primary, fontWeight: FontWeight.w700))),
            for (final n in g.items) _Row(n: n, now: now, onTap: () => _open(n)),
          ],
          _footer(),
        ],
      );
    });
  }

  Widget _footer() {
    if (c.loadingMore.value) return const Padding(padding: EdgeInsets.all(EmSpacing.s16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
    if (c.moreFailed.value) {
      return Padding(
        padding: const EdgeInsets.all(EmSpacing.s8),
        child: Center(child: EmTextAction(key: const Key('notif_more_retry'), label: "Couldn't load more. Tap to retry", icon: Icons.refresh_rounded, onPressed: c.loadMore)),
      );
    }
    if (!c.hasMore) return Padding(padding: const EdgeInsets.all(EmSpacing.s16), child: Center(child: Text('You have reached the end', key: const Key('notif_end'), style: EmType.caption.copyWith(color: EmColors.textSecondary))));
    return const SizedBox(height: EmSpacing.s24);
  }

  void _open(AppNotification n) {
    final target = c.tap(n);
    if (target == null) return;
    if (target.route == Routes.homeMessages && Get.isRegistered<HomeShellController>()) {
      // The inbox is a TAB of the shell that is already underneath: go back to it and select the tab (pushing a second HomeShell crashed with
      // "setState() or markNeedsBuild() called during build" on the device - found by the local end-to-end run).
      if (Get.key.currentState?.canPop() ?? false) Get.back();
      Get.find<HomeShellController>().changeTab(HomeShellController.messagesTab);
      return;
    }
    Get.toNamed(target.route);
  }
}

class _Row extends StatelessWidget {
  final AppNotification n;
  final DateTime now;
  final VoidCallback onTap;
  const _Row({required this.n, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final at = n.createdAt;
    final (icon, tone) = _iconFor(n.type);
    // Unread = a dot AND a heavier title (and "Unread" is spoken); read rows are the plain weight with no dot.
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        key: Key('notif_${n.id}'),
        onTap: onTap,
        padding: const EdgeInsets.all(EmSpacing.s12),
        semanticLabel: [if (!n.isRead) 'Unread', n.title, if (n.body.isNotEmpty) n.body, if (at != null) relativeTime(now, at)].join(', '),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.background, borderRadius: EmRadius.smAll), child: Icon(icon, color: tone.foreground, size: 20)),
          const SizedBox(width: EmSpacing.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800))),
                if (!n.isRead) Container(key: Key('notif_unread_${n.id}'), margin: const EdgeInsetsDirectional.only(start: EmSpacing.s8, top: EmSpacing.s4), width: 10, height: 10, decoration: const BoxDecoration(color: EmColors.primary, shape: BoxShape.circle)),
              ]),
              if (n.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
              if (at != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text('${relativeTime(now, at)} · ${absoluteTime(at)}', style: EmType.caption.copyWith(color: EmColors.textSecondary))),
            ]),
          ),
        ]),
      ),
    );
  }

  static (IconData, EmTone) _iconFor(String type) => switch (type) {
        'message' => (Icons.chat_bubble_outline_rounded, EmTone.info),
        'ptm' => (Icons.handshake_outlined, EmTone.info),
        'substitution' => (Icons.swap_horiz_rounded, EmTone.warning),
        'lesson_plan' => (Icons.edit_note_rounded, EmTone.success),
        'homework' => (Icons.menu_book_outlined, EmTone.info),
        'leave_status' || 'leave_decision' => (Icons.event_busy_outlined, EmTone.warning),
        _ => (Icons.notifications_none_rounded, EmTone.neutral),
      };
}
