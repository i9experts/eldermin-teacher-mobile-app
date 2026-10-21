import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../controllers/timetable_controller.dart';
import 'widgets/timetable_widgets.dart';
import '../../../../core/design/design.dart';

/// My timetable (`/timetable`, and the tab in the Attendance slot for teachers
/// who are not class teachers): read-only day and week views of MY periods.
/// [embedded] renders just the body (no Scaffold/AppBar) for the HomeShell tab.
class TimetableScreen extends GetView<TimetableController> {
  final bool embedded;
  const TimetableScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = Obx(() => _body());
    if (embedded) return body;
    return EmScaffold(
      appBar: EmAppBar(title: 'Timetable'),
      body: body,
    );
  }

  Widget _body() {
    final c = controller;
    final s = c.week.value;
    final isDay = c.mode.value == TimetableMode.day;
    final days = c.weekDays;
    final selected = c.selectedDate.value;
    final withClasses = <DateTime>{
      if (s.hasData) for (final d in days) if (periodsOnDay(s.data!, dayIndexOf(d)).isNotEmpty) d,
    };
    return ScreenStateView<List<TeacherPeriod>>(
      state: s,
      onRefresh: c.refreshWeek,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.event_busy_outlined,
      emptyTitle: 'No periods this week',
      emptySubtitle: 'Nothing is timetabled for you in the week of ${weekRangeLabel(c.weekStart)}.',
      header: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: EmCaptionLine(c.isTodaySelected ? 'Today · ${longDateOf(c.today)}' : longDateOf(selected))),
          if (!c.isTodaySelected) TextButton(onPressed: c.goToToday, child: Text('Today', style: EmType.label.copyWith(color: EmColors.primary))),
        ]),
        EmSegmentedTabs<TimetableMode>(
          segments: const [EmSegment(TimetableMode.day, 'Day'), EmSegment(TimetableMode.week, 'Week')],
          selected: isDay ? TimetableMode.day : TimetableMode.week,
          onChanged: c.setMode,
        ),
        const SizedBox(height: EmSpacing.row),
        TimetableWeekStrip(
          days: days,
          selected: selected,
          today: c.today,
          withClasses: withClasses,
          onSelect: c.selectDate,
          onPrevious: c.previousWeek,
          onNext: c.nextWeek,
        ),
        const SizedBox(height: EmSpacing.row),
      ],
      builder: (periods) => [
        if (c.showsWeekTags) const WeekCycleNote(),
        if (isDay) ..._day(c, selected) else ..._week(c, days),
      ],
    );
  }

  List<Widget> _day(TimetableController c, DateTime date) {
    final items = c.dayPeriods(date);
    if (items.isEmpty) {
      return [
        AppCard(
          key: const Key('timetable_day_empty'),
          child: Row(children: [
            const ExcludeSemantics(child: Icon(Icons.wb_sunny_outlined, color: EmColors.textSecondary, size: 24)),
            const SizedBox(width: EmSpacing.row),
            Expanded(child: Text(c.isTodaySelected ? 'No classes today' : 'No classes on ${weekdayShort(date)} ${dayMonthShort(date)}', style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
          ]),
        ),
      ];
    }
    return [for (final (i, p) in items.indexed) KeyedSubtree(key: ValueKey('period_$i'), child: PeriodTile(item: p))];
  }

  List<Widget> _week(TimetableController c, List<DateTime> days) {
    final out = <Widget>[];
    for (final d in days) {
      final items = c.dayPeriods(d);
      final isToday = sameDate(d, c.today);
      out.add(Padding(
        key: ValueKey('week_day_${d.year}-${d.month}-${d.day}'),
        padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8),
        child: Row(children: [
          Flexible(child: Text('${weekdayShort(d)} ${dayMonthShort(d)}', style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          if (isToday) ...[const SizedBox(width: EmSpacing.s8), const AppTag('Today', style: EmTone.info)],
          const Spacer(),
          Text(items.isEmpty ? 'No classes' : '${items.length} ${items.length == 1 ? 'period' : 'periods'}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
      ));
      for (final (i, p) in items.indexed) {
        out.add(KeyedSubtree(key: ValueKey('week_${d.day}_period_$i'), child: PeriodTile(item: p, compact: true)));
      }
    }
    return out;
  }
}
