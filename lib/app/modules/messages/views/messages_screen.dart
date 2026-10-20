import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/home/messaging.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../classes/views/classes_screen.dart' show TabHeading;
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
            const Expanded(child: TabHeading(title: 'Messages')),
            EmIconCircleButton(
              key: const Key('messages_new'),
              icon: Icons.add_rounded,
              semanticLabel: 'New message',
              onTap: c.startNew,
            ),
          ]),
          Text('Talk to parents inside the app. Contact details are never shared.',
              style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13)),
          const SizedBox(height: EmSpacing.s12),
          EmSegmentedTabs<InboxFilter>(
            key: const Key('messages_filter'),
            segments: const [EmSegment(InboxFilter.open, 'Open'), EmSegment(InboxFilter.closed, 'Closed')],
            selected: c.filter.value,
            onChanged: c.selectFilter,
          ),
          const SizedBox(height: EmSpacing.s16),
        ],
        builder: (_) => [
          for (final t in rows) ThreadRow(thread: t, now: c.clock(), onTap: () => c.open(t)),
          if (c.mayBeCut)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: EmSpacing.s4),
              child: Text('Showing the 100 most recent conversations.', key: const Key('messages_cut'), textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ),
        ],
      );
    });
    return embedded ? body : EmScaffold(appBar: EmAppBar(title: 'Messages'), body: body);
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
    final when = at == null ? null : relativeTime(now, at);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.row),
      child: EmCard(
        key: Key('thread_${t.id}'),
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s16, vertical: EmSpacing.s12),
        semanticLabel: [who, if (about.isNotEmpty) about, if (unread) 'unread', if (when != null) when, if (t.isClosed) 'closed'].join(', '),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EmAvatar(initials: _initials(who), size: 44),
          const SizedBox(width: EmSpacing.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink, fontSize: 15, fontWeight: unread ? FontWeight.w700 : FontWeight.w600))),
                if (when != null) ...[
                  const SizedBox(width: EmSpacing.s8),
                  Tooltip(
                    message: absoluteTime(at!),
                    child: Text(when, maxLines: 1, softWrap: false, style: EmType.caption.copyWith(color: unread ? EmColors.primary : EmColors.textSecondary, fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ],
              ]),
              if (about.isNotEmpty) Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: EmSpacing.s4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    t.lastMessagePreview.isEmpty ? 'No messages yet' : t.lastMessagePreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EmType.body.copyWith(color: unread ? EmColors.ink : EmColors.textSecondary, fontWeight: unread ? FontWeight.w600 : FontWeight.w400, fontSize: 13),
                  ),
                ),
                if (t.isClosed) const Padding(padding: EdgeInsetsDirectional.only(start: EmSpacing.s8), child: EmChip.status(label: 'Closed', tone: EmTone.neutral)),
                if (unread)
                  Container(
                    key: Key('unread_${t.id}'),
                    margin: const EdgeInsetsDirectional.only(start: EmSpacing.s8, top: 4),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: EmColors.primary, shape: BoxShape.circle),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _initials(String name) {
    // Drop "(...)" notes and honorifics so "Mrs Malik" is "M", not "MM"-style noise like "M(".
    final cleaned = name.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'^\s*(mr|mrs|ms|miss|dr)\.?\s+', caseSensitive: false), '');
    final parts = cleaned.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return '$a$b'.toUpperCase();
  }
}
