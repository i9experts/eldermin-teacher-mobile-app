import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/models/json_helpers.dart' show wireDay;
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../home/models/section_state.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/circulars_controller.dart';
import 'calendar_widgets.dart';
import 'circular_sheet.dart';
import '../../../../core/design/design.dart';

/// School calendar (`/calendar`, read only): Calendar tab (month grid or agenda + the selected day's list) and Circulars tab.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final circ = Get.find<CircularsController>();
    return DefaultTabController(
      length: 2,
      child: EmScaffold(
        appBar: EmAppBar(
          title: 'School calendar',
          bottom: _PaddedTabs(TabBar(
            indicatorColor: EmColors.ink,
            labelColor: EmColors.ink,
            unselectedLabelColor: EmColors.textSecondary,
            labelStyle: EmType.label.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: EmType.label,
            tabs: [
              const Tab(key: Key('tab_calendar'), text: 'Calendar'),
              Tab(
                key: const Key('tab_circulars'),
                child: Obx(() {
                  final n = circ.pendingAcks;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Circulars'),
                    if (n > 0) ...[
                      const SizedBox(width: EmSpacing.s8),
                      Semantics(
                        label: '$n to acknowledge',
                        child: Container(key: const Key('circulars_pending_badge'), padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s8, vertical: EmSpacing.s2), decoration: const BoxDecoration(color: EmColors.warningContainer, borderRadius: EmRadius.pillAll), child: Text('$n', style: EmType.caption.copyWith(fontWeight: FontWeight.w800, color: EmColors.onWarningContainer))),
                      ),
                    ],
                  ]);
                }),
              ),
            ],
          )),
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
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s24),
          children: [
            if (blocked)
              ..._blocked(st)
            else ...[
              EmSegmentedTabs<bool>(key: const Key('cal_mode'), segments: const [EmSegment(false, 'Month'), EmSegment(true, 'Agenda')], selected: c.agenda.value, onChanged: c.setAgenda),
              const SizedBox(height: EmSpacing.s12),
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
          padding: const EdgeInsets.only(top: EmSpacing.s24),
          child: st.status == SectionStatus.forbidden
              ? AppEmptyView(key: const Key('screen_forbidden'), icon: Icons.lock_outline_rounded, title: st.forbiddenDetail ?? "You don't have access", subtitle: st.forbiddenDetail != null ? null : "Your account isn't allowed to view the calendar. Ask your school admin if you think this is a mistake.")
              : const AppEmptyView(key: Key('screen_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet', subtitle: 'The school calendar has not been deployed to your school’s server.'),
        )
      ];

  Widget _grid() {
    c.version.value; // markers rebuild when entries arrive
    final focused = c.focusedDay.value, selected = c.selectedDay.value;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(EmSpacing.s4, EmSpacing.s4, EmSpacing.s4, EmSpacing.s8),
      child: TableCalendar<CalendarEntry>(
        key: const Key('cal_grid'),
        firstDay: DateTime.utc(2000, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: focused,
        selectedDayPredicate: (d) => d.year == selected.year && d.month == selected.month && d.day == selected.day,
        currentDay: c.today,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: EmType.label.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink),
          leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: EmColors.ink),
          rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: EmColors.ink),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600), weekendStyle: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600)),
        // Today and the selected day differ by more than colour: today is an outlined ring with a bold number, the selected day a solid filled circle.
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          defaultTextStyle: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w500),
          weekendTextStyle: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w500),
          outsideTextStyle: EmType.label.copyWith(color: EmColors.textTertiary, fontWeight: FontWeight.w400),
          selectedTextStyle: EmType.label.copyWith(color: EmColors.onPrimary, fontWeight: FontWeight.w700),
          todayTextStyle: EmType.label.copyWith(color: EmColors.primary, fontWeight: FontWeight.w800),
          selectedDecoration: const BoxDecoration(color: EmColors.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: EmColors.primaryTint, shape: BoxShape.circle, border: Border.all(color: EmColors.primary, width: 2)),
          markersMaxCount: 3,
        ),
        eventLoader: (d) => c.entriesOn(d),
        calendarBuilders: CalendarBuilders<CalendarEntry>(
          markerBuilder: (ctx, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            return Positioned(
              bottom: EmSpacing.s2,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in events.take(3)) Container(margin: const EdgeInsets.symmetric(horizontal: EmSpacing.s2), width: 6, height: 6, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
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
      EmIconCircleButton(key: const Key('agenda_prev'), icon: Icons.chevron_left_rounded, semanticLabel: 'Previous month', tooltip: 'Previous month', onTap: () => c.setFocused(DateTime(month.year, month.month - 1, 1))),
      Expanded(child: Center(child: Text('${months[month.month - 1]} ${month.year}', style: EmType.label.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink)))),
      EmIconCircleButton(key: const Key('agenda_next'), icon: Icons.chevron_right_rounded, semanticLabel: 'Next month', tooltip: 'Next month', onTap: () => c.setFocused(DateTime(month.year, month.month + 1, 1))),
    ]);
  }

  List<Widget> _body(SectionState<List<CalendarEntry>> st) {
    switch (st.status) {
      case SectionStatus.loading:
        return [AppShimmer(key: const Key('screen_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())))];
      case SectionStatus.error:
        if (st.isStale) return [RefreshFailedBanner(message: st.message, onRetry: c.reload), ...(c.agenda.value ? _agenda() : [CalendarLegend(types: st.data!.map((e) => e.type)), ..._dayList()])];
        return [Padding(padding: const EdgeInsets.only(top: EmSpacing.s16), child: AppErrorView(key: const Key('screen_error'), message: st.message ?? 'Something went wrong', onRetry: c.reload))];
      case SectionStatus.empty:
        return [
          if (!c.agenda.value) ..._dayList(),
          if (c.agenda.value) const Padding(padding: EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: Key('screen_empty'), icon: Icons.event_available_rounded, title: 'Nothing scheduled this month', subtitle: 'Holidays, exams and school dates appear here when the school adds them.')),
          if (!c.agenda.value) Padding(padding: const EdgeInsets.only(top: EmSpacing.s12), child: Text('No school dates in this month.', key: const Key('month_empty_note'), style: EmType.caption.copyWith(color: EmColors.textSecondary))),
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
        padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8),
        child: Row(children: [
          Expanded(child: Text(dayHeading(d, c.today) + (d == c.today ? ' (today)' : ''), key: const Key('day_heading'), style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w800))),
          if (d != c.today) EmTextAction(key: const Key('cal_today'), label: 'Today', onPressed: c.goToToday),
        ]),
      ),
      if (list.isEmpty) AppCard(key: const Key('day_empty'), child: Text('Nothing scheduled for this day.', style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
      for (final e in list) CalendarEntryCard(entry: e, onTap: () => showCalendarEntrySheet(Get.context!, e)),
    ];
  }

  List<Widget> _agenda() {
    final map = c.agendaFor(c.focusedDay.value);
    return [
      CalendarLegend(types: c.entriesInMonth(c.focusedDay.value).map((e) => e.type)),
      for (final day in map.entries) ...[
        Padding(padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8), child: Text(dayHeading(day.key, c.today) + (day.key == c.today ? ' (today)' : ''), key: ValueKey('agenda_day_${wireDay(day.key)}'), style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w800))),
        for (final e in day.value) CalendarEntryCard(entry: e, onTap: () => showCalendarEntrySheet(Get.context!, e)),
      ],
    ];
  }
}

/// Detail of a calendar entry (bottom sheet).
Future<void> showCalendarEntrySheet(BuildContext context, CalendarEntry e) {
  return EmBottomSheet.showPanel<void>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        key: const Key('cal_entry_sheet'),
        padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.screenH),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CalendarTypeLabel(color: e.color, label: e.type.label, dotSize: 12),
            if (e.source == 'academics' || e.source == 'assessments') ...[const SizedBox(width: EmSpacing.s8), Flexible(child: Text(e.source == 'academics' ? 'from Academics' : 'from Assessments', style: EmType.caption.copyWith(color: EmColors.textSecondary)))],
          ]),
          const SizedBox(height: EmSpacing.s8),
          Text(e.title, style: EmType.heading.copyWith(color: EmColors.ink)),
          const SizedBox(height: EmSpacing.s12),
          _row(Icons.event_rounded, entryDaysText(e)),
          _row(Icons.schedule_rounded, e.timeLabel()),
          if (e.gradeLevels.isNotEmpty) _row(Icons.school_outlined, 'Grades: ${e.gradeLevels.join(', ')}'),
          if (e.description.isNotEmpty) ...[const SizedBox(height: EmSpacing.s12), Text(e.description, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400))],
        ]),
      ),
    ),
  );
}

Widget _row(IconData i, String t) => Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: ExcludeSemantics(child: Icon(i, size: 18, color: EmColors.textSecondary))), const SizedBox(width: EmSpacing.s8), Expanded(child: Text(t, style: EmType.label.copyWith(color: EmColors.ink)))]));

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
        showServerForbidden: true,
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
    // New = a dot AND a heavier title (and "New" is spoken); the tags carry the acknowledgment state in words.
    return AppCard(
      key: ValueKey('circular_${x.id}'),
      onTap: () => showCircularSheet(context, c, x),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isNew) Semantics(label: 'New', child: Container(key: ValueKey('circular_new_${x.id}'), margin: const EdgeInsetsDirectional.only(end: EmSpacing.s8, top: EmSpacing.s4), width: 10, height: 10, decoration: const BoxDecoration(color: EmColors.primary, shape: BoxShape.circle))),
          Expanded(child: Text(x.title, style: EmType.body.copyWith(fontWeight: isNew ? FontWeight.w800 : FontWeight.w600, color: EmColors.ink))),
          if (x.urgent) const Padding(padding: EdgeInsetsDirectional.only(start: EmSpacing.s8), child: AppTag('URGENT', style: EmTone.error)),
        ]),
        const SizedBox(height: EmSpacing.s8),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppTag(x.categoryLabel.toUpperCase(), style: EmTone.neutral),
          if (when != null) Text(fullDay(when.toLocal()), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
        if (x.bodyText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text(x.bodyText, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
        if (needs) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: AppTag('ACKNOWLEDGMENT REQUESTED', key: ValueKey('circular_needs_ack_${x.id}'), style: EmTone.warning)),
        if (done) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: AppTag('ACKNOWLEDGED', key: ValueKey('circular_acked_${x.id}'), style: EmTone.success)),
      ]),
    );
  }
}

/// Gives the bar's `TabBar` the screen's 20dp side margins (the Em app bar pads its title row, not its bottom slot).
class _PaddedTabs extends StatelessWidget implements PreferredSizeWidget {
  const _PaddedTabs(this.tabs);
  final TabBar tabs;

  @override
  Size get preferredSize => tabs.preferredSize;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH), child: tabs);
}
