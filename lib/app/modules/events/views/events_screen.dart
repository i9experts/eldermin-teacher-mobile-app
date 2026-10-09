import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/events_controller.dart';

/// School events (`/events`, read only): Upcoming and Past. No tickets, orders, attendees or fees.
class EventsScreen extends GetView<EventsController> {
  const EventsScreen({super.key});
  EventsController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Obx(() => ScreenStateView<List<SchoolEvent>>(
            state: c.state.value,
            onRefresh: () => c.load(userInitiated: true),
            onRetry: () => c.load(userInitiated: true),
            emptyIcon: Icons.celebration_outlined,
            emptyTitle: 'No events',
            emptySubtitle: 'School events appear here when the school publishes them.',
            builder: (_) {
              final up = c.upcoming, past = c.past;
              return [
                if (up.isNotEmpty) ...[const SubHeading('Upcoming'), for (final e in up) EventCard(event: e)],
                if (past.isNotEmpty) ...[const SubHeading('Past'), for (final e in past) EventCard(event: e, dim: true)],
              ];
            },
          )),
    );
  }
}

class EventCard extends StatelessWidget {
  final SchoolEvent event;
  final bool dim;
  const EventCard({super.key, required this.event, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final e = event;
    return AppCard(
      key: ValueKey('event_${e.id}'),
      onTap: () => Get.toNamed(Routes.eventDetail.replaceFirst(':id', e.id), arguments: e),
      child: Opacity(
        opacity: dim ? 0.75 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: CustomText(text: e.title, fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor)),
            if (e.cancelled) const AppTag('CANCELLED', style: TagStyle.red),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(child: CustomText(text: eventWhenText(e), fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
          if (e.venueName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [const Icon(Icons.place_outlined, size: 13, color: AppColors.muted), const SizedBox(width: 4), Expanded(child: CustomText(text: e.venueName, fontSize: 12, color: AppColors.muted))])),
          const SizedBox(height: 6),
          AppTag(e.categoryLabel.toUpperCase(), style: TagStyle.neutral),
        ]),
      ),
    );
  }
}
