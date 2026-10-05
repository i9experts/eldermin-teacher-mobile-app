import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../controllers/timetable_controller.dart';
import 'widgets/timetable_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const CustomText(text: 'Timetable', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
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
        ScreenHeader(
          title: 'Timetable',
          caption: c.isTodaySelected ? 'Today · ${longDateOf(c.today)}' : longDateOf(selected),
          selectLabel: c.isTodaySelected ? null : 'Today',
          onSelectTap: c.isTodaySelected ? null : c.goToToday,
        ),
        SegmentedControl(
          options: const ['Day', 'Week'],
          selectedIndex: isDay ? 0 : 1,
          onChanged: (i) => c.setMode(i == 0 ? TimetableMode.day : TimetableMode.week),
        ),
        const SizedBox(height: 10),
        TimetableWeekStrip(
          days: days,
          selected: selected,
          today: c.today,
          withClasses: withClasses,
          onSelect: c.selectDate,
          onPrevious: c.previousWeek,
          onNext: c.nextWeek,
        ),
        const SizedBox(height: 12),
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
            const Icon(Icons.wb_sunny_outlined, color: AppColors.faint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: CustomText(
                text: c.isTodaySelected ? 'No classes today' : 'No classes on ${weekdayShort(date)} ${dayMonthShort(date)}',
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
                fontSize: 13,
              ),
            ),
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
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(children: [
          CustomText(text: '${weekdayShort(d)} ${dayMonthShort(d)}', color: AppColors.primaryColor, fontSize: 13, fontWeight: FontWeight.w800),
          if (isToday) ...[const SizedBox(width: 8), const AppTag('Today', style: TagStyle.info)],
          const Spacer(),
          CustomText(text: items.isEmpty ? 'No classes' : '${items.length} ${items.length == 1 ? 'period' : 'periods'}', color: AppColors.faint, fontSize: 10),
        ]),
      ));
      for (final (i, p) in items.indexed) {
        out.add(KeyedSubtree(key: ValueKey('week_${d.day}_period_$i'), child: PeriodTile(item: p, compact: true)));
      }
    }
    return out;
  }
}
