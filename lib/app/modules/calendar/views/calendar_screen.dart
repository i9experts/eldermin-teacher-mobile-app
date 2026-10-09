import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/models/json_helpers.dart' show wireDay;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/custom_text.dart';
import '../../home/models/section_state.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/circulars_controller.dart';
import 'calendar_widgets.dart';
import 'circular_sheet.dart';

/// School calendar (`/calendar`, read only): Calendar tab (month grid or agenda + the selected day's list) and Circulars tab.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final circ = Get.find<CircularsController>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('School calendar'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFFBCD3E5),
            tabs: [
              const Tab(key: Key('tab_calendar'), text: 'Calendar'),
              Tab(
                key: const Key('tab_circulars'),
                child: Obx(() {
                  final n = circ.pendingAcks;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Circulars'),
                    if (n > 0) ...[
                      const SizedBox(width: 6),
                      Container(key: const Key('circulars_pending_badge'), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(9)), child: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                    ],
                  ]);
                }),
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [_CalendarTab(), _CircularsTab()]),
      ),
    );
  }
}

// ───────────────────────────── Calendar tab ─────────────────────────────

class _CalendarTab extends GetView<CalendarController> {
  const _CalendarTab();
  CalendarController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final st = c.state.value;
      final month = c.focusedDay.value;
      final blocked = st.status == SectionStatus.forbidden || st.status == SectionStatus.unavailable;
      return RefreshIndicator(
        onRefresh: c.reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (blocked)
              ..._blocked(st)
            else ...[
              SegmentedControl(key: const Key('cal_mode'), options: const ['Month', 'Agenda'], selectedIndex: c.agenda.value ? 1 : 0, onChanged: (i) => c.setAgenda(i == 1)),
              const SizedBox(height: 10),
              if (c.agenda.value) _agendaHeader(month) else _grid(),
              ..._body(st),
            ],
          ],
        ),
      );
    });
  }

  List<Widget> _blocked(SectionState st) => [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: st.status == SectionStatus.forbidden
              ? const AppEmptyView(key: Key('screen_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access", subtitle: "Your account isn't allowed to view the calendar. Ask your school admin if you think this is a mistake.")
              : const AppEmptyView(key: Key('screen_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet', subtitle: 'The school calendar has not been deployed to your school’s server.'),
        )
      ];

  Widget _grid() {
    c.version.value; // markers rebuild when entries arrive
    final focused = c.focusedDay.value, selected = c.selectedDay.value;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: TableCalendar<CalendarEntry>(
        key: const Key('cal_grid'),
        firstDay: DateTime.utc(2000, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: focused,
        selectedDayPredicate: (d) => d.year == selected.year && d.month == selected.month && d.day == selected.day,
        currentDay: c.today,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          selectedDecoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppColors.sky, shape: BoxShape.circle),
          markersMaxCount: 3,
        ),
        eventLoader: (d) => c.entriesOn(d),
        calendarBuilders: CalendarBuilders<CalendarEntry>(
          markerBuilder: (ctx, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            return Positioned(
              bottom: 3,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in events.take(3)) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 5.5, height: 5.5, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
              ]),
            );
          },
        ),
        onDaySelected: (sel, foc) => c.selectDay(DateTime(sel.year, sel.month, sel.day)),
        onPageChanged: (foc) => c.setFocused(DateTime(foc.year, foc.month, foc.day)),
      ),
    );
  }

  Widget _agendaHeader(DateTime month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return Row(children: [
      IconButton(key: const Key('agenda_prev'), onPressed: () => c.setFocused(DateTime(month.year, month.month - 1, 1)), icon: const Icon(Icons.chevron_left_rounded)),
      Expanded(child: Center(child: CustomText(text: '${months[month.month - 1]} ${month.year}', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14))),
      IconButton(key: const Key('agenda_next'), onPressed: () => c.setFocused(DateTime(month.year, month.month + 1, 1)), icon: const Icon(Icons.chevron_right_rounded)),
    ]);
  }

  List<Widget> _body(SectionState<List<CalendarEntry>> st) {
    switch (st.status) {
      case SectionStatus.loading:
        return [AppShimmer(key: const Key('screen_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())))];
      case SectionStatus.error:
        return [Padding(padding: const EdgeInsets.only(top: 16), child: AppErrorView(key: const Key('screen_error'), message: st.message ?? 'Something went wrong', onRetry: c.reload))];
      case SectionStatus.empty:
        return [
          if (!c.agenda.value) ..._dayList(),
          if (c.agenda.value) const Padding(padding: EdgeInsets.only(top: 24), child: AppEmptyView(key: Key('screen_empty'), icon: Icons.event_available_rounded, title: 'Nothing scheduled this month', subtitle: 'Holidays, exams and school dates appear here when the school adds them.')),
          if (!c.agenda.value) const Padding(padding: EdgeInsets.only(top: 12), child: CustomText(key: Key('month_empty_note'), text: 'No school dates in this month.', fontSize: 11.5, color: AppColors.faint)),
        ];
      case SectionStatus.data:
        return c.agenda.value ? _agenda() : [CalendarLegend(types: st.data!.map((e) => e.type)), ..._dayList()];
      default:
        return const [];
    }
  }

  List<Widget> _dayList() {
    final d = c.selectedDay.value;
    final list = c.entriesOn(d);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(children: [
          Expanded(child: CustomText(key: const Key('day_heading'), text: dayHeading(d, c.today) + (d == c.today ? ' (today)' : ''), color: AppColors.primaryColor, fontSize: 13, fontWeight: FontWeight.w800)),
          if (d != c.today) TextButton(key: const Key('cal_today'), onPressed: c.goToToday, child: const Text('Today')),
        ]),
      ),
      if (list.isEmpty) const AppCard(key: Key('day_empty'), child: CustomText(text: 'Nothing scheduled for this day.', fontSize: 12.5, color: AppColors.muted)),
      for (final e in list) CalendarEntryCard(entry: e, onTap: () => showCalendarEntrySheet(Get.context!, e)),
    ];
  }

  List<Widget> _agenda() {
    final map = c.agendaFor(c.focusedDay.value);
    return [
      CalendarLegend(types: c.entriesInMonth(c.focusedDay.value).map((e) => e.type)),
      for (final day in map.entries) ...[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: CustomText(key: ValueKey('agenda_day_${wireDay(day.key)}'), text: dayHeading(day.key, c.today) + (day.key == c.today ? ' (today)' : ''), color: AppColors.primaryColor, fontSize: 13, fontWeight: FontWeight.w800)),
        for (final e in day.value) CalendarEntryCard(entry: e, onTap: () => showCalendarEntrySheet(Get.context!, e)),
      ],
    ];
  }
}

/// Detail of a calendar entry (bottom sheet).
Future<void> showCalendarEntrySheet(BuildContext context, CalendarEntry e) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        key: const Key('cal_entry_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            CustomText(text: e.type.label.toUpperCase(), fontSize: 10.5, fontWeight: FontWeight.w800, color: e.color),
            if (e.source == 'academics' || e.source == 'assessments') ...[const SizedBox(width: 8), CustomText(text: e.source == 'academics' ? 'from Academics' : 'from Assessments', fontSize: 10.5, color: AppColors.faint)],
          ]),
          const SizedBox(height: 8),
          CustomText(text: e.title, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          const SizedBox(height: 10),
          _row(Icons.event_rounded, entryDaysText(e)),
          _row(Icons.schedule_rounded, e.timeLabel()),
          if (e.gradeLevels.isNotEmpty) _row(Icons.school_outlined, 'Grades: ${e.gradeLevels.join(', ')}'),
          if (e.description.isNotEmpty) ...[const SizedBox(height: 10), CustomText(text: e.description, fontSize: 13, color: AppColors.ink, height: 1.45)],
        ]),
      ),
    ),
  );
}

Widget _row(IconData i, String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(i, size: 16, color: AppColors.muted), const SizedBox(width: 8), Expanded(child: CustomText(text: t, fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600))]));

// ───────────────────────────── Circulars tab ─────────────────────────────

class _CircularsTab extends GetView<CircularsController> {
  const _CircularsTab();
  CircularsController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      c.acked.length;
      c.opened.length;
      return ScreenStateView<List<Circular>>(
        state: c.state.value,
        onRefresh: () => c.load(userInitiated: true),
        onRetry: () => c.load(userInitiated: true),
        emptyIcon: Icons.campaign_outlined,
        emptyTitle: 'No circulars',
        emptySubtitle: 'Notices the school sends to staff appear here.',
        builder: (list) => [for (final x in list) _CircularCard(c: c, circular: x)],
      );
    });
  }
}

class _CircularCard extends StatelessWidget {
  final CircularsController c;
  final Circular circular;
  const _CircularCard({required this.c, required this.circular});

  @override
  Widget build(BuildContext context) {
    final x = circular;
    final isNew = c.isNew(x);
    final needs = c.needsAck(x);
    final done = x.requiresAcknowledgment && c.acked.contains(x.id);
    final when = x.when;
    return AppCard(
      key: ValueKey('circular_${x.id}'),
      onTap: () => showCircularSheet(context, c, x),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isNew) Container(key: ValueKey('circular_new_${x.id}'), margin: const EdgeInsets.only(right: 8), width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryColorLight, shape: BoxShape.circle)),
          Expanded(child: CustomText(text: x.title, fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor)),
          if (x.urgent) const AppTag('URGENT', style: TagStyle.red),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          AppTag(x.categoryLabel.toUpperCase(), style: TagStyle.neutral),
          const SizedBox(width: 8),
          if (when != null) CustomText(text: fullDay(when.toLocal()), fontSize: 11, color: AppColors.muted),
        ]),
        if (x.bodyText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: x.bodyText, fontSize: 12, color: AppColors.muted, height: 1.35, maxLines: 2, overflow: TextOverflow.ellipsis)),
        if (needs) Padding(padding: const EdgeInsets.only(top: 8), child: AppTag('ACKNOWLEDGMENT REQUESTED', key: ValueKey('circular_needs_ack_${x.id}'), style: TagStyle.amber)),
        if (done) Padding(padding: const EdgeInsets.only(top: 8), child: AppTag('ACKNOWLEDGED', key: ValueKey('circular_acked_${x.id}'), style: TagStyle.green)),
      ]),
    );
  }
}
