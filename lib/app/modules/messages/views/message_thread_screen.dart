import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../controllers/chat_controller.dart';
import '../../../../core/design/design.dart';

/// One conversation (`/messages/:threadId`). The controller is created here, tagged by thread id, and removed with the screen, so opening
/// another thread never shows the previous one's messages. A controller registered beforehand (tests) is reused.
class MessageThreadScreen extends StatefulWidget {
  final String? threadId;
  const MessageThreadScreen({super.key, this.threadId});

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  late final String id = widget.threadId ?? Get.parameters['threadId'] ?? '';
  late final ChatController c;
  bool _owned = false;
  final _scroll = ScrollController();
  int _lastCount = 0;
  bool _stick = true;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ChatController>(tag: id)) {
      c = Get.find<ChatController>(tag: id);
    } else {
      c = Get.put(ChatController(threadId: id), tag: id);
      _owned = true;
    }
    _scroll.addListener(_onScroll);
    _worker = ever(c.messages, (_) => _onMessages());
  }

  @override
  void dispose() {
    _worker?.dispose();
    _scroll.dispose();
    if (_owned && Get.isRegistered<ChatController>(tag: id)) Get.delete<ChatController>(tag: id);
    super.dispose();
  }

  bool get _atBottom => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.position.pixels < 80;

  void _onScroll() {
    _stick = _atBottom;
    if (_stick) c.clearNewIncoming();
  }

  /// Keeps the teacher's place: jump to the end for the first load and for the teacher's own messages, follow new messages only when
  /// already at the bottom; otherwise leave the scroll position alone (the "New messages" chip offers the jump).
  void _onMessages() {
    final n = c.messages.length;
    final grew = n > _lastCount;
    final first = _lastCount == 0 && n > 0;
    final mine = n > 0 && c.messages.last.fromMe && c.messages.last.state != SendState.sent;
    _lastCount = n;
    if (!grew) return;
    if (first || mine || _stick) WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(animate: !first));
  }

  void _toBottom({bool animate = true, int retries = 8}) {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(end, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(end);
      // A long thread (hundreds of bubbles) is laid out lazily: maxScrollExtent is only an estimate until the last items are built, so one jump can
      // stop short of the newest message (seen on the simulator with 500 messages). Re-jump on the next frames (bounded) until the end stops moving.
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients && _scroll.position.maxScrollExtent - _scroll.position.pixels > 1) _toBottom(animate: false, retries: retries - 1);
        });
      }
    }
    c.clearNewIncoming();
  }

  Future<void> _confirmClose() async {
    final ok = await ConfirmDialog.show(
      title: 'Close this conversation?',
      message: 'Neither you nor the guardian will be able to send messages in it. You can still read it.',
      confirmLabel: 'Close conversation',
      destructive: true,
    );
    if (!ok) return;
    final done = await c.close();
    if (done) {
      ToastUtil.showToast('Conversation closed');
    } else if (mounted) {
      final f = c.closeFailure.value;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f?.message ?? "Couldn't close this conversation.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(
        titleWidget: Obx(() {
          final t = c.thread;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Text(key: const Key('chat_title'), t == null || t.guardianName.isEmpty ? 'Conversation' : t.guardianName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)),
            if (t != null && (t.studentName.isNotEmpty || t.subject.isNotEmpty))
              Text([if (t.studentName.isNotEmpty) 're ${t.studentName}', if (t.subject.isNotEmpty) t.subject].join(' · '), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ]);
        }),
        actions: [
          Obx(() => c.canCompose
              ? Builder(
                  builder: (btn) => EmIconCircleButton(
                    key: const Key('chat_menu'),
                    icon: Icons.more_horiz_rounded,
                    semanticLabel: 'More options',
                    tooltip: 'More options',
                    onTap: () async {
                      final box = btn.findRenderObject() as RenderBox;
                      final overlay = Overlay.of(btn).context.findRenderObject() as RenderBox;
                      final rect = RelativeRect.fromRect(box.localToGlobal(Offset.zero, ancestor: overlay) & box.size, Offset.zero & overlay.size);
                      final v = await showMenu<String>(
                        context: btn,
                        position: rect,
                        items: const [PopupMenuItem(value: 'close', key: Key('chat_close'), child: Text('Close conversation'))],
                      );
                      if (v == 'close') _confirmClose();
                    },
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final st = c.load.value;
    switch (st.status) {
      case SectionStatus.loading:
        return AppShimmer(key: const Key('chat_loading'), child: Column(children: List.generate(5, (_) => const ShimmerListRowSkeleton())));
      case SectionStatus.error:
        return AppErrorView(key: const Key('chat_error'), message: st.message ?? 'Something went wrong', onRetry: c.loadThread);
      case SectionStatus.forbidden:
        return const AppEmptyView(key: Key('chat_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access", subtitle: "Your account isn't allowed to open this conversation.");
      case SectionStatus.unavailable:
        return const AppEmptyView(key: Key('chat_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet', subtitle: 'Messaging has not been deployed to your school’s server.');
      case SectionStatus.empty:
        return const AppEmptyView(key: Key('chat_not_found'), icon: Icons.chat_bubble_outline_rounded, title: 'Conversation not found', subtitle: 'It may have been removed, or it is not one of yours.');
      case SectionStatus.data:
        return Column(children: [
          if (c.pollFailing.value) const _Banner(key: Key('chat_poll_failing'), text: "Can't refresh right now. Showing what we have; trying again."),
          if (c.truncated.value) const _Banner(key: Key('chat_truncated'), text: 'This conversation is very long: only its latest 500 messages are shown.'),
          Expanded(child: Stack(children: [_list(), _newChip()])),
          _composer(),
        ]);
    }
  }

  Widget _newChip() => Obx(() {
        final n = c.newIncoming.value;
        if (n == 0) return const SizedBox.shrink();
        return Positioned(
          bottom: EmSpacing.s12,
          left: 0,
          right: 0,
          child: Center(
            child: ActionChip(
              key: const Key('chat_new_chip'),
              backgroundColor: EmColors.primary,
              side: BorderSide.none,
              avatar: const Icon(Icons.arrow_downward_rounded, color: EmColors.onPrimary, size: 16),
              label: Text(n == 1 ? 'New message' : '$n new messages', style: EmType.caption.copyWith(color: EmColors.onPrimary, fontWeight: FontWeight.w700)),
              onPressed: () => _toBottom(),
            ),
          ),
        );
      });

  Widget _list() {
    final msgs = c.messages.toList();
    if (msgs.isEmpty) {
      return const AppEmptyView(key: Key('chat_empty'), icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet');
    }
    final now = DateTime.now();
    final children = <Widget>[];
    String? lastDay;
    for (final m in msgs) {
      final at = m.createdAt;
      final key = at == null ? null : dayKey(at);
      if (key != null && key != lastDay) {
        children.add(Padding(padding: const EdgeInsets.symmetric(vertical: EmSpacing.s12), child: Center(child: Text(dayHeading(now, at!), style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w700)))));
        lastDay = key;
      }
      children.add(_Bubble(message: m, now: now, onRetry: () => c.retry(m.clientId), onDiscard: () => c.discard(m.clientId)));
    }
    return ListView(key: const Key('chat_list'), controller: _scroll, padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s16), children: children);
  }

  Widget _composer() {
    if (c.closed.value) {
      return SafeArea(
        top: false,
        child: Container(
          key: const Key('chat_closed_banner'),
          width: double.infinity,
          padding: const EdgeInsets.all(EmSpacing.s16),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: EmSpacing.s2), child: Icon(Icons.lock_outline_rounded, size: 20, color: EmColors.textSecondary)),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text('This conversation is closed. You can read it, but no one can send new messages.', style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          ]),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(EmSpacing.s12, EmSpacing.s8, EmSpacing.s8, EmSpacing.s8),
        decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input'),
              controller: c.composer,
              minLines: 1,
              maxLines: 5,
              maxLength: NewThreadRequest.messageMax,
              textCapitalization: TextCapitalization.sentences,
              style: EmType.body.copyWith(color: EmColors.ink),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: 'Write a message',
                hintStyle: EmType.body.copyWith(color: EmColors.textTertiary),
                filled: true,
                fillColor: EmColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: EmSpacing.s16, vertical: EmSpacing.s12),
                border: OutlineInputBorder(borderRadius: EmRadius.tileAll, borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: EmSpacing.s8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: c.composer,
            builder: (_, v, __) => IconButton.filled(
              key: const Key('chat_send'),
              tooltip: 'Send message',
              style: IconButton.styleFrom(backgroundColor: EmColors.primary, disabledBackgroundColor: EmColors.disabled, minimumSize: const Size(EmSpacing.minTouch, EmSpacing.minTouch)),
              onPressed: v.text.trim().isEmpty ? null : c.submit,
              icon: Icon(Icons.send_rounded, color: v.text.trim().isEmpty ? EmColors.onDisabled : EmColors.onPrimary, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, 0), child: EmInfoBanner(text: text, tone: EmTone.warning, icon: Icons.sync_problem_rounded));
}

/// A message bubble. Sent vs received is told apart by more than colour: sent bubbles sit at the end edge with the small "tail" corner at their
/// bottom end, received bubbles at the start edge with the tail at their bottom start; a screen reader hears "You" or "Guardian" first.
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  const _Bubble({required this.message, required this.now, required this.onRetry, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.fromMe;
    final failed = m.state == SendState.failed;
    final bg = mine ? (failed ? EmColors.errorContainer : EmColors.primary) : EmColors.surface;
    final fg = mine ? (failed ? EmColors.onErrorContainer : EmColors.onPrimary) : EmColors.ink;
    final at = m.createdAt;
    const big = Radius.circular(EmRadius.md);
    const tail = Radius.circular(EmSpacing.s4);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            key: Key('msg_${m.key}'),
            margin: const EdgeInsets.only(top: EmSpacing.s4),
            padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s8 + EmSpacing.s2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadiusDirectional.only(topStart: big, topEnd: big, bottomStart: mine ? big : tail, bottomEnd: mine ? tail : big),
              border: Border.all(color: failed ? EmColors.error : (mine ? EmColors.primary : EmColors.border)),
            ),
            child: Semantics(
              label: mine ? 'You' : 'Guardian',
              child: Text(m.body, softWrap: true, style: EmType.body.copyWith(color: fg, fontWeight: FontWeight.w500)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: EmSpacing.s2),
            child: switch (m.state) {
              SendState.sending => Text('Sending…', key: const Key('msg_sending'), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
              SendState.failed => Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.end, spacing: EmSpacing.s4, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: EmColors.error),
                    const SizedBox(width: EmSpacing.s4),
                    Flexible(child: Text('Not sent — ${m.failureText}', key: const Key('msg_failed'), style: EmType.caption.copyWith(color: EmColors.error, fontWeight: FontWeight.w700))),
                  ]),
                  if (m.canRetry) EmTextAction(key: Key('retry_${m.clientId}'), label: 'Retry', onPressed: onRetry),
                  EmTextAction(key: Key('discard_${m.clientId}'), label: 'Remove', destructive: true, onPressed: onDiscard),
                ]),
              SendState.sent => at == null ? const SizedBox.shrink() : Tooltip(message: absoluteTime(at), child: Text(bubbleTime(now, at), style: EmType.caption.copyWith(color: EmColors.textSecondary))),
            },
          ),
        ]),
      ),
    );
  }
}
