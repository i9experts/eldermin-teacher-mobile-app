import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../components/external_link.dart';
import '../controllers/events_controller.dart';

/// Event detail (`/events/:id`, read only): when, where, sessions, description. Nothing about tickets, attendees or fees.
class EventDetailScreen extends GetView<EventDetailController> {
  const EventDetailScreen({super.key});
  EventDetailController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: Obx(() => ScreenStateView<SchoolEvent>(
            state: c.state.value,
            onRefresh: () => c.load(userInitiated: true),
            onRetry: () => c.load(userInitiated: true),
            builder: (e) => [
              Row(children: [
                AppTag(e.categoryLabel.toUpperCase(), style: TagStyle.neutral),
                if (e.cancelled) ...[const SizedBox(width: 8), const AppTag('CANCELLED', style: TagStyle.red)],
                if (e.status == 'completed') ...[const SizedBox(width: 8), const AppTag('COMPLETED', style: TagStyle.green)],
              ]),
              const SizedBox(height: 10),
              CustomText(key: const Key('event_title'), text: e.title, fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
              const SizedBox(height: 14),
              if (e.sessions.isEmpty) const AppCard(key: Key('event_no_sessions'), child: CustomText(text: 'Date to be confirmed', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
              for (final s in e.sessions)
                AppCard(
                  key: ValueKey('event_session_${s.start.millisecondsSinceEpoch}'),
                  child: Row(children: [
                    const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (s.label.isNotEmpty) CustomText(text: s.label, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted),
                        CustomText(text: sessionText(s), fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ]),
                    ),
                  ]),
                ),
              if (e.venueName.isNotEmpty || e.venueAddress.isNotEmpty)
                AppCard(
                  key: const Key('event_venue'),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.place_outlined, size: 18, color: AppColors.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (e.venueName.isNotEmpty) CustomText(text: e.venueName, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                      if (e.venueAddress.isNotEmpty) CustomText(text: e.venueAddress, fontSize: 12, color: AppColors.muted),
                    ])),
                  ]),
                ),
              if (e.descriptionText.isNotEmpty) ...[
                const SubHeading('About'),
                CustomText(key: const Key('event_description'), text: e.descriptionText, fontSize: 13.5, color: AppColors.ink, height: 1.5),
              ],
              if (e.descriptionLinks.isNotEmpty) ...[
                const SubHeading('Links'),
                for (final u in e.descriptionLinks)
                  InkWell(
                    key: ValueKey('event_link_$u'),
                    onTap: () => ExternalLinks.openWithConfirm(u),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.blue), const SizedBox(width: 8), Expanded(child: CustomText(text: Uri.parse(u).host, fontSize: 12.5, color: AppColors.blue))])),
                  ),
              ],
            ],
          )),
    );
  }
}
