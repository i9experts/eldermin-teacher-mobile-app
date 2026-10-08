import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../controllers/chat_controller.dart';

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

  void _toBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(end, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(end);
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
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final t = c.thread;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            CustomText(key: const Key('chat_title'), text: t == null || t.guardianName.isEmpty ? 'Conversation' : t.guardianName, color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (t != null && (t.studentName.isNotEmpty || t.subject.isNotEmpty))
              CustomText(text: [if (t.studentName.isNotEmpty) 're ${t.studentName}', if (t.subject.isNotEmpty) t.subject].join(' · '), color: const Color(0xFFBCD3E5), fontSize: 11, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]);
        }),
        actions: [
          Obx(() => c.canCompose
              ? PopupMenuButton<String>(
                  key: const Key('chat_menu'),
                  onSelected: (v) {
                    if (v == 'close') _confirmClose();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'close', key: Key('chat_close'), child: Text('Close conversation'))],
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
          if (c.pollFailing.value) const _Banner(key: Key('chat_poll_failing'), text: "Can't refresh right now. Showing what we have; trying again.", color: AppColors.amberBg, fg: AppColors.amberText),
          if (c.truncated.value) const _Banner(key: Key('chat_truncated'), text: 'This conversation is very long: only its first 500 messages can be shown.', color: AppColors.amberBg, fg: AppColors.amberText),
          Expanded(child: Stack(children: [_list(), _newChip()])),
          _composer(),
        ]);
    }
  }

  Widget _newChip() => Obx(() {
        final n = c.newIncoming.value;
        if (n == 0) return const SizedBox.shrink();
        return Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: ActionChip(
              key: const Key('chat_new_chip'),
              backgroundColor: AppColors.primaryColor,
              avatar: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
              label: CustomText(text: n == 1 ? 'New message' : '$n new messages', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
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
        children.add(Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: CustomText(text: dayHeading(now, at!), fontSize: 11, color: AppColors.faint, fontWeight: FontWeight.w700))));
        lastDay = key;
      }
      children.add(_Bubble(message: m, now: now, onRetry: () => c.retry(m.clientId), onDiscard: () => c.discard(m.clientId)));
    }
    return ListView(key: const Key('chat_list'), controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: children);
  }

  Widget _composer() {
    if (c.closed.value) {
      return SafeArea(
        top: false,
        child: Container(
          key: const Key('chat_closed_banner'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: AppColors.canvas, border: Border(top: BorderSide(color: AppColors.line))),
          child: const Row(children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(child: CustomText(text: 'This conversation is closed. You can read it, but no one can send new messages.', color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input'),
              controller: c.composer,
              minLines: 1,
              maxLines: 5,
              maxLength: NewThreadRequest.messageMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: 'Write a message',
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: c.composer,
            builder: (_, v, __) => IconButton.filled(
              key: const Key('chat_send'),
              style: IconButton.styleFrom(backgroundColor: AppColors.primaryColor, disabledBackgroundColor: AppColors.buttonDisableColor),
              onPressed: v.text.trim().isEmpty ? null : c.submit,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final Color fg;
  const _Banner({super.key, required this.text, required this.color, required this.fg});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, color: color, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: CustomText(text: text, color: fg, fontSize: 11, fontWeight: FontWeight.w700));
}

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
    final bg = mine ? (failed ? AppColors.redBg : AppColors.primaryColor) : Colors.white;
    final fg = mine ? (failed ? AppColors.redText : Colors.white) : AppColors.ink;
    final at = m.createdAt;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            key: Key('msg_${m.key}'),
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16)),
              border: Border.all(color: failed ? AppColors.redText.withOpacity(0.4) : (mine ? AppColors.primaryColor : AppColors.line)),
            ),
            child: Text(m.body, style: TextStyle(color: fg, fontSize: 14, height: 1.35)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: switch (m.state) {
              SendState.sending => const CustomText(key: Key('msg_sending'), text: 'Sending…', fontSize: 10, color: AppColors.faint),
              SendState.failed => Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                  CustomText(key: const Key('msg_failed'), text: 'Not sent — ${m.failureText}', fontSize: 11, color: AppColors.redText, fontWeight: FontWeight.w700),
                  if (m.canRetry) InkWell(key: Key('retry_${m.clientId}'), onTap: onRetry, child: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: CustomText(text: 'Retry', fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w800))),
                  InkWell(key: Key('discard_${m.clientId}'), onTap: onDiscard, child: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: CustomText(text: 'Remove', fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700))),
                ]),
              SendState.sent => at == null ? const SizedBox.shrink() : Tooltip(message: absoluteTime(at), child: CustomText(text: bubbleTime(now, at), fontSize: 10, color: AppColors.faint)),
            },
          ),
        ]),
      ),
    );
  }
}
