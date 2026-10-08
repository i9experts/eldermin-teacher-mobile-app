import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../home/models/section_state.dart';
import '../controllers/messages_controller.dart';

/// Messages inbox (the Messages tab). Conversations with guardians about a student; newest first. OPEN list = the state the shell's 60 s
/// badge poll keeps fresh; CLOSED is fetched when chosen.
class MessagesScreen extends GetView<MessagesController> {
  final bool embedded;
  const MessagesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      final c = controller;
      var st = c.state;
      final rows = c.rows;
      if (st.hasData && rows.isEmpty) st = const SectionState.empty();
      final isOpen = c.filter.value == InboxFilter.open;
      return ScreenStateView<ThreadsResult>(
        state: st,
        onRefresh: c.reload,
        onRetry: c.retry,
        emptyIcon: Icons.forum_outlined,
        emptyTitle: isOpen ? 'No open conversations' : 'No closed conversations',
        emptySubtitle: isOpen ? 'Start one with the + button, or from a student\'s page.' : 'Conversations you close show up here.',
        header: [
          Row(children: [
            const Expanded(child: CustomText(text: 'Messages', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
            IconButton.filled(
              key: const Key('messages_new'),
              tooltip: 'New message',
              style: IconButton.styleFrom(backgroundColor: AppColors.primaryColor),
              onPressed: c.startNew,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const CustomText(text: 'Talk to parents inside the app. Contact details are never shared.', fontSize: 11, color: AppColors.muted),
          const SizedBox(height: 12),
          SegmentedControl(
            key: const Key('messages_filter'),
            options: const ['Open', 'Closed'],
            selectedIndex: c.filter.value.index,
            onChanged: (i) => c.selectFilter(InboxFilter.values[i]),
          ),
          const SizedBox(height: 12),
        ],
        builder: (_) => [
          for (final t in rows) ThreadRow(thread: t, now: c.clock(), onTap: () => c.open(t)),
          if (c.mayBeCut)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: CustomText(key: Key('messages_cut'), text: 'Showing the 100 most recent conversations.', fontSize: 11, color: AppColors.muted, textAlign: TextAlign.center),
            ),
        ],
      );
    });
    return embedded ? body : Scaffold(appBar: AppBar(title: const Text('Messages')), body: body);
  }
}

class ThreadRow extends StatelessWidget {
  final MessageThread thread;
  final DateTime now;
  final VoidCallback onTap;
  const ThreadRow({super.key, required this.thread, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = thread;
    final unread = t.staffHasUnread && !t.isClosed;
    final at = t.lastMessageAt;
    final who = t.guardianName.isEmpty ? 'Guardian' : t.guardianName;
    final about = [if (t.studentName.isNotEmpty) 're ${t.studentName}', if (t.subject.isNotEmpty) t.subject].join(' · ');
    return AppCard(
      key: Key('thread_${t.id}'),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(14)),
          child: CustomText(text: _initials(who), color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: CustomText(text: who, fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 13, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (at != null)
                Tooltip(message: absoluteTime(at), child: CustomText(text: relativeTime(now, at), fontSize: 10, color: unread ? AppColors.blue : AppColors.faint, fontWeight: unread ? FontWeight.w800 : FontWeight.w400)),
            ]),
            if (about.isNotEmpty) CustomText(text: about, fontSize: 11, color: AppColors.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Expanded(
                child: CustomText(
                  text: t.lastMessagePreview.isEmpty ? 'No messages yet' : t.lastMessagePreview,
                  fontSize: 12,
                  color: unread ? AppColors.ink : AppColors.muted,
                  fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t.isClosed) const Padding(padding: EdgeInsets.only(left: 6), child: AppTag('Closed', style: TagStyle.neutral)),
              if (unread) Container(key: Key('unread_${t.id}'), margin: const EdgeInsets.only(left: 8), width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle)),
            ]),
          ]),
        ),
      ]),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return '$a$b'.toUpperCase();
  }
}
