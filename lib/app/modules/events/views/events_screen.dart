import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/events_controller.dart';
import '../../../../core/design/design.dart';

/// School events (`/events`, read only): Upcoming and Past. No tickets, orders, attendees or fees.
class EventsScreen extends GetView<EventsController> {
  const EventsScreen({super.key});
  EventsController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Events'),
      body: Obx(() => ScreenStateView<List<SchoolEvent>>(
            state: c.state.value,
            showServerForbidden: true,
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

/// Cancelled and past events are told apart in words (a CANCELLED tag; "Past" has its own heading), never by dimming alone.
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
        opacity: dim ? 0.85 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(e.title, style: EmType.body.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink))),
            if (e.cancelled) const Padding(padding: EdgeInsetsDirectional.only(start: EmSpacing.s8), child: AppTag('CANCELLED', style: TagStyle.red)),
          ]),
          const SizedBox(height: EmSpacing.s8),
          _Line(icon: Icons.schedule_rounded, text: eventWhenText(e), bold: true),
          if (e.venueName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: _Line(icon: Icons.place_outlined, text: e.venueName)),
          const SizedBox(height: EmSpacing.s8),
          AppTag(e.categoryLabel.toUpperCase(), style: TagStyle.neutral),
        ]),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;
  const _Line({required this.icon, required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: ExcludeSemantics(child: Icon(icon, size: 16, color: EmColors.textSecondary))),
        const SizedBox(width: EmSpacing.s8),
        Expanded(child: Text(text, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.w500))),
      ]);
}
