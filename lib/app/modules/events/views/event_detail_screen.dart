import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/external_link.dart';
import '../controllers/events_controller.dart';
import '../../../../core/design/design.dart';

/// Event detail (`/events/:id`, read only): when, where, sessions, description. Nothing about tickets, attendees or fees.
class EventDetailScreen extends GetView<EventDetailController> {
  const EventDetailScreen({super.key});
  EventDetailController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Event'),
      body: Obx(() => ScreenStateView<SchoolEvent>(
            state: c.state.value,
            showServerForbidden: true,
            onRefresh: () => c.load(userInitiated: true),
            onRetry: () => c.load(userInitiated: true),
            builder: (e) => [
              Row(children: [
                AppTag(e.categoryLabel.toUpperCase(), style: EmTone.neutral),
                if (e.cancelled) ...[const SizedBox(width: EmSpacing.s8), const AppTag('CANCELLED', style: EmTone.error)],
                if (e.status == 'completed') ...[const SizedBox(width: EmSpacing.s8), const AppTag('COMPLETED', style: EmTone.success)],
              ]),
              const SizedBox(height: EmSpacing.s12),
              Text(e.title, key: const Key('event_title'), style: EmType.title.copyWith(color: EmColors.ink)),
              const SizedBox(height: EmSpacing.block),
              if (e.sessions.isEmpty) AppCard(key: const Key('event_no_sessions'), child: Text('Date to be confirmed', style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary))),
              for (final s in e.sessions)
                AppCard(
                  key: ValueKey('event_session_${s.start.millisecondsSinceEpoch}'),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const ExcludeSemantics(child: Icon(Icons.event_rounded, size: 20, color: EmColors.primary)),
                    const SizedBox(width: EmSpacing.s12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (s.label.isNotEmpty) Text(s.label, style: EmType.caption.copyWith(fontWeight: FontWeight.w800, color: EmColors.textSecondary)),
                        Text(sessionText(s), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
                      ]),
                    ),
                  ]),
                ),
              if (e.venueName.isNotEmpty || e.venueAddress.isNotEmpty)
                AppCard(
                  key: const Key('event_venue'),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const ExcludeSemantics(child: Icon(Icons.place_outlined, size: 20, color: EmColors.primary)),
                    const SizedBox(width: EmSpacing.s12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (e.venueName.isNotEmpty) Text(e.venueName, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
                      if (e.venueAddress.isNotEmpty) Text(e.venueAddress, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                    ])),
                  ]),
                ),
              if (e.descriptionText.isNotEmpty) ...[
                const SubHeading('About'),
                Text(e.descriptionText, key: const Key('event_description'), softWrap: true, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5)),
              ],
              if (e.descriptionLinks.isNotEmpty) ...[
                const SubHeading('Links'),
                for (final u in e.descriptionLinks)
                  InkWell(
                    key: ValueKey('event_link_$u'),
                    onTap: () => ExternalLinks.openWithConfirm(u),
                    child: ConstrainedBox(constraints: const BoxConstraints(minHeight: EmSpacing.minTouch), child: Row(children: [const Icon(Icons.open_in_new_rounded, size: 18, color: EmColors.primary), const SizedBox(width: EmSpacing.s8), Expanded(child: Text(Uri.parse(u).host, style: EmType.label.copyWith(color: EmColors.primary, decoration: TextDecoration.underline)))])),
                  ),
              ],
            ],
          )),
    );
  }
}
