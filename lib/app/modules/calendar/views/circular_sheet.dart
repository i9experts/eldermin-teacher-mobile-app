import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../common/action_failure.dart';
import '../../../components/custom_text.dart';
import '../../../components/external_link.dart';
import '../controllers/circulars_controller.dart';

/// Circular detail (bottom sheet): plain-text body (the server's HTML is flattened), links and attachments open only after confirmation, and the
/// Acknowledge button when the circular asks for it.
Future<void> showCircularSheet(BuildContext context, CircularsController c, Circular x) {
  c.markOpened(x);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(children: [
          AppTag(x.categoryLabel.toUpperCase(), style: TagStyle.neutral),
          if (x.urgent) ...[const SizedBox(width: 8), const AppTag('URGENT', style: TagStyle.red)],
          const Spacer(),
          if (when != null) CustomText(text: fullDay(when.toLocal()), fontSize: 11, color: AppColors.muted),
        ]),
        const SizedBox(height: 10),
        CustomText(text: x.title, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
        const SizedBox(height: 10),
        CustomText(key: const Key('circular_body'), text: x.bodyText.isEmpty ? 'No text.' : x.bodyText, fontSize: 13.5, color: AppColors.ink, height: 1.5),
        if (x.bodyLinks.isNotEmpty || x.attachmentUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          const CustomText(text: 'Links and attachments', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted),
          const SizedBox(height: 6),
          for (final u in [...x.attachmentUrls, ...x.bodyLinks.where((l) => !x.attachmentUrls.contains(l))])
            InkWell(
              key: ValueKey('circular_link_$u'),
              onTap: () => ExternalLinks.openWithConfirm(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: CustomText(text: Uri.parse(u).host + (Uri.parse(u).path.length > 1 ? Uri.parse(u).path : ''), fontSize: 12.5, color: AppColors.blue, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
        ],
        if (x.requiresAcknowledgment) ...[const SizedBox(height: 18), _AckBox(c: c, circular: x)],
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
        return Container(
          key: const Key('circular_ack_done'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Row(children: [
            Icon(Icons.check_circle_rounded, color: AppColors.greenText, size: 18),
            SizedBox(width: 8),
            Expanded(child: CustomText(text: 'You acknowledged this circular.', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.greenText)),
          ]),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CustomText(text: 'The school asks you to confirm that you have read this circular.', fontSize: 12, color: AppColors.muted, height: 1.4),
        if (failure != null) Padding(padding: const EdgeInsets.only(top: 8), child: CustomText(key: const Key('circular_ack_error'), text: failure.message, fontSize: 12, color: AppColors.redText, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('circular_ack_button'),
            onPressed: busy ? null : () => c.acknowledge(circular),
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'I have read this', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ]);
    });
  }
}
