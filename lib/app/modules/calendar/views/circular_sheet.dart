import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart' show AppTag;
import '../../../common/action_failure.dart';
import '../../../components/external_link.dart';
import '../controllers/circulars_controller.dart';
import '../../../../core/design/design.dart';

/// Circular detail (bottom sheet): plain-text body (the server's HTML is flattened), links and attachments open only after confirmation, and the
/// Acknowledge button when the circular asks for it.
Future<void> showCircularSheet(BuildContext context, CircularsController c, Circular x) {
  c.markOpened(x);
  return EmBottomSheet.showPanel<void>(
    context,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => CircularDetail(c: c, circular: x, scroll: scroll),
    ),
  );
}

class CircularDetail extends StatelessWidget {
  final CircularsController c;
  final Circular circular;
  final ScrollController? scroll;
  const CircularDetail({super.key, required this.c, required this.circular, this.scroll});

  @override
  Widget build(BuildContext context) {
    final x = circular;
    final when = x.when;
    return ListView(
      key: const Key('circular_sheet'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s32),
      children: [
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppTag(x.categoryLabel.toUpperCase(), style: TagStyle.neutral),
          if (x.urgent) const AppTag('URGENT', style: TagStyle.red),
          if (when != null) Text(fullDay(when.toLocal()), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
        const SizedBox(height: EmSpacing.s12),
        Text(x.title, style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s12),
        Text(x.bodyText.isEmpty ? 'No text.' : x.bodyText, key: const Key('circular_body'), softWrap: true, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5)),
        if (x.bodyLinks.isNotEmpty || x.attachmentUrls.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s16),
          Text('Links and attachments', style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          for (final u in [...x.attachmentUrls, ...x.bodyLinks.where((l) => !x.attachmentUrls.contains(l))])
            InkWell(
              key: ValueKey('circular_link_$u'),
              onTap: () => ExternalLinks.openWithConfirm(u),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
                child: Row(children: [
                  const Icon(Icons.open_in_new_rounded, size: 18, color: EmColors.primary),
                  const SizedBox(width: EmSpacing.s8),
                  Expanded(child: Text(Uri.parse(u).host + (Uri.parse(u).path.length > 1 ? Uri.parse(u).path : ''), maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.primary, decoration: TextDecoration.underline))),
                ]),
              ),
            ),
        ],
        if (x.requiresAcknowledgment) ...[const SizedBox(height: EmSpacing.s20), _AckBox(c: c, circular: x)],
      ],
    );
  }
}

class _AckBox extends StatelessWidget {
  final CircularsController c;
  final Circular circular;
  const _AckBox({required this.c, required this.circular});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final done = c.acked.contains(circular.id);
      final busy = c.acking.contains(circular.id);
      final ActionFailure? failure = c.ackFailure[circular.id];
      if (done) {
        return const EmInfoBanner(key: Key('circular_ack_done'), tone: EmTone.success, icon: Icons.check_circle_rounded, text: 'You acknowledged this circular.');
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('The school asks you to confirm that you have read this circular.', style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: EmColors.error),
              const SizedBox(width: EmSpacing.s8),
              Expanded(child: Text(failure.message, key: const Key('circular_ack_error'), style: EmType.label.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
            ]),
          ),
        const SizedBox(height: EmSpacing.s12),
        EmPrimaryButton(key: const Key('circular_ack_button'), label: 'I have read this', loading: busy, onPressed: busy ? null : () => c.acknowledge(circular)),
      ]);
    });
  }
}
