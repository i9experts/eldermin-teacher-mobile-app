import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/notification_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../controllers/notifications_controller.dart';

/// Notifications inbox (`/notifications`): grouped by day, unread dot, tap = mark read + open what it is about. Infinite scroll by cursor.
class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({super.key});

  NotificationsController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Obx(() {
            final enabled = (c.unreadCount.value ?? 0) > 0 && !c.markingAll.value && c.state.value.hasData;
            return TextButton(
              key: const Key('notif_mark_all'),
              onPressed: enabled ? () => _markAll(context) : null,
              child: Text('Mark all read', style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontWeight: FontWeight.w700, fontSize: 12)),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        header: [
          SegmentedControl(key: const Key('notif_filter'), options: const ['All', 'Unread'], selectedIndex: unreadOnly ? 1 : 0, onChanged: (i) => c.setUnreadOnly(i == 1)),
          const SizedBox(height: 12),
          if (refreshError != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: CustomText(key: const Key('notif_refresh_error'), text: "Couldn't refresh: $refreshError", color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
        builder: (_) => [
          for (final g in c.groups) ...[
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: CustomText(text: g.heading, color: AppColors.primaryColor, fontSize: 12, fontWeight: FontWeight.w800)),
            for (final n in g.items) _Row(n: n, now: now, onTap: () => _open(n)),
          ],
          _footer(),
        ],
      );
    });
  }

  Widget _footer() {
    if (c.loadingMore.value) return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
    if (c.moreFailed.value) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(child: TextButton(key: const Key('notif_more_retry'), onPressed: c.loadMore, child: const Text("Couldn't load more. Tap to retry"))),
      );
    }
    if (!c.hasMore) return const Padding(padding: EdgeInsets.all(14), child: Center(child: CustomText(key: Key('notif_end'), text: 'You have reached the end', fontSize: 11, color: AppColors.faint)));
    return const SizedBox(height: 24);
  }

  void _open(AppNotification n) {
    final target = c.tap(n);
    if (target != null) Get.toNamed(target.route);
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
    final (icon, color) = _iconFor(n.type);
    return AppCard(
      key: Key('notif_${n.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: CustomText(text: n.title, fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 13, color: AppColors.primaryColor, maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (!n.isRead) Container(key: Key('notif_unread_${n.id}'), margin: const EdgeInsets.only(left: 8, top: 4), width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle)),
            ]),
            if (n.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: CustomText(text: n.body, fontSize: 12, color: AppColors.muted, maxLines: 3, overflow: TextOverflow.ellipsis)),
            if (at != null) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: '${relativeTime(now, at)} · ${absoluteTime(at)}', fontSize: 10, color: AppColors.faint)),
          ]),
        ),
      ]),
    );
  }

  static (IconData, Color) _iconFor(String type) => switch (type) {
        'message' => (Icons.chat_bubble_outline_rounded, AppColors.blue),
        'ptm' => (Icons.handshake_outlined, AppColors.purple),
        'substitution' => (Icons.swap_horiz_rounded, AppColors.amberText),
        'lesson_plan' => (Icons.edit_note_rounded, AppColors.green),
        'homework' => (Icons.menu_book_outlined, AppColors.blue),
        'leave_status' || 'leave_decision' => (Icons.event_busy_outlined, AppColors.amberText),
        _ => (Icons.notifications_none_rounded, AppColors.muted),
      };
}
