import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/models/classroom/attendance_month.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/attendance_controller.dart' show kAttendanceEditWindowDays;
import '../controllers/attendance_history_controller.dart';
import 'widgets/attendance_widgets.dart';
import '../../../../core/design/design.dart';
import '../../../common/write_access.dart';

/// Attendance history (`/attendance/history`): a month calendar with a coloured marker on every day that
/// has records, the per-day summary counts, and a day detail with an "Edit" shortcut where editing is allowed
/// (today and the previous [kAttendanceEditWindowDays] days; older days are read-only).
class AttendanceHistoryScreen extends GetView<AttendanceHistoryController> {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Attendance history'),
      body: Obx(() {
        if (!controller.daily.allowed) {
          return const AppEmptyView(
            key: Key('attendance_not_class_teacher'),
            icon: Icons.lock_outline_rounded,
            title: 'Attendance is for class teachers',
            subtitle: 'Only the class teacher of a class can see its attendance history.',
          );
        }
        return _body();
      }),
    );
  }

  Widget _body() {
    final c = controller;
    final s = c.month.value;
    final cls = c.daily.myClass!;
    // Reactive reads happen here (inside the Obx); the builder and the calendar run outside its tracking.
    final selected = c.selectedDay.value;
    final focused = c.focusedMonth.value;
    final roster = c.daily.students_;
    final editable = c.canEditSelected;
    return ScreenStateView<MonthAttendance>(
      state: s,
      onRefresh: c.reload,
      onRetry: c.reload,
      emptyIcon: Icons.groups_outlined,
      emptyTitle: 'No students in your class',
      emptySubtitle: 'There are no active students in ${cls.label} yet.',
      header: [
        EmCaptionLine(cls.label),
        _Calendar(controller: c, month: s.data, selected: selected, focusedMonth: focused),
        const SizedBox(height: EmSpacing.row),
      ],
      builder: (m) => _detail(m, selected, roster, editable),
    );
  }

  List<Widget> _detail(MonthAttendance m, DateTime d, List<StudentSummary> roster, bool editable) {
    final c = controller;
    final day = m.day(ymdOf(d));
    final title = '${longDateOf(d)}${sameSelected(d, c.today) ? ' · Today' : ''}';
    return [
      SectionRow(title: title),
      if (day == null)
        EmCard(
          key: const Key('history_day_empty'),
          child: Row(children: [
            const ExcludeSemantics(child: Icon(Icons.event_busy_outlined, color: EmColors.textSecondary, size: 24)),
            const SizedBox(width: EmSpacing.row),
            Expanded(child: Text(d.isAfter(c.today) ? 'This day is in the future.' : 'No attendance was recorded for this day.', style: EmType.body.copyWith(color: EmColors.ink))),
          ]),
        )
      else
        EmCard(
          key: const Key('history_day_card'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(day.complete ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded, size: 18, color: day.complete ? EmColors.onSuccessContainer : EmColors.onWarningContainer),
              const SizedBox(width: EmSpacing.s8),
              Expanded(
                child: Text(
                  'Marked ${day.marked} of ${m.rosterSize}${day.complete ? '' : ' (incomplete)'}',
                  style: EmType.label.copyWith(color: day.complete ? EmColors.onSuccessContainer : EmColors.onWarningContainer),
                ),
              ),
            ]),
            const SizedBox(height: EmSpacing.s12),
            StatusCountPills(counts: day.counts, showZero: true),
            ..._notPresent(day, roster),
          ]),
        ),
      if (!d.isAfter(c.today)) ...[
        const SizedBox(height: EmSpacing.row),
        if (!canWriteAttendance)
          const SizedBox.shrink()
        else if (editable)
          EmPrimaryButton(
            key: const Key('history_edit_button'),
            icon: Icons.edit_calendar_outlined,
            label: day == null ? 'Mark this day' : 'Edit this day',
            onPressed: () => Get.toNamed('${Routes.attendanceMark}?date=${ymdOf(d)}'),
          )
        else
          Text('Older than $kAttendanceEditWindowDays days: view only.', key: const Key('history_read_only'), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
      ],
    ];
  }

  List<Widget> _notPresent(DayAttendance day, List<StudentSummary> roster) {
    final byId = {for (final s in roster) s.id: s};
    final rows = <Widget>[];
    for (final st in [AttendanceStatus.absent, AttendanceStatus.late, AttendanceStatus.excused, AttendanceStatus.halfDay]) {
      final names = [
        for (final e in day.byStudent.entries)
          if (e.value == st) byId[e.key]?.fullName ?? 'Student'
      ]..sort();
      if (names.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: EmSpacing.s12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.label, style: EmType.label.copyWith(color: statusColors(st).fg)),
          const SizedBox(height: EmSpacing.s2),
          Text(names.join(', '), style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
        ]),
      ));
    }
    return rows;
  }
}

bool sameSelected(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _Calendar extends StatelessWidget {
  final AttendanceHistoryController controller;
  final MonthAttendance? month;
  final DateTime selected;
  final DateTime focusedMonth;
  const _Calendar({required this.controller, required this.month, required this.selected, required this.focusedMonth});

  Color _toneColor(DayTone t) {
    switch (t) {
      case DayTone.allPresent:
        return EmColors.success;
      case DayTone.attention:
        return EmColors.warning;
      case DayTone.absences:
        return EmColors.error;
      case DayTone.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final today = c.today;
    final dayStyle = EmType.body.copyWith(color: EmColors.ink);
    return EmCard(
      key: const Key('history_calendar'),
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: Column(children: [
        TableCalendar<void>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(today.year, today.month, today.day),
          focusedDay: _focused(today),
          selectedDayPredicate: (d) => isSameDay(d, selected),
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          rowHeight: EmSpacing.minTouch,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: EmType.bodyLarge.copyWith(color: EmColors.ink),
            leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: EmColors.ink),
            rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: EmColors.ink),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: EmType.caption.copyWith(color: EmColors.textSecondary), weekendStyle: EmType.caption.copyWith(color: EmColors.textSecondary)),
          calendarStyle: CalendarStyle(
            defaultTextStyle: dayStyle,
            weekendTextStyle: dayStyle,
            todayDecoration: BoxDecoration(color: EmColors.primaryContainer, shape: BoxShape.circle, border: Border.all(color: EmColors.primary)),
            todayTextStyle: dayStyle.copyWith(fontWeight: FontWeight.w600),
            selectedDecoration: const BoxDecoration(color: EmColors.primary, shape: BoxShape.circle),
            selectedTextStyle: dayStyle.copyWith(color: EmColors.onPrimary, fontWeight: FontWeight.w600),
            disabledTextStyle: dayStyle.copyWith(color: EmColors.onDisabled),
            outsideDaysVisible: false,
          ),
          onDaySelected: (sel, focused) => c.selectDay(sel),
          onPageChanged: (focused) => c.focusMonth(focused),
          calendarBuilders: CalendarBuilders<void>(
            markerBuilder: (context, day, events) {
              final entry = month?.day(ymdOf(day));
              if (entry == null) return null;
              final tone = entry.tone;
              if (tone == DayTone.none) return null;
              return Positioned(
                bottom: EmSpacing.s4,
                child: Container(
                  key: ValueKey('marker_${ymdOf(day)}'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.complete ? _toneColor(tone) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _toneColor(tone), width: 1.6), // hollow = not every student marked
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(EmSpacing.s12, 0, EmSpacing.s12, EmSpacing.s4),
          child: Wrap(spacing: EmSpacing.s16, runSpacing: EmSpacing.s4, children: [
            _Legend(color: EmColors.success, label: 'All present'),
            _Legend(color: EmColors.warning, label: 'Late / leave'),
            _Legend(color: EmColors.error, label: 'Absences'),
            _Legend(color: EmColors.textTertiary, label: 'Hollow = not everyone marked', hollow: true),
          ]),
        ),
      ]),
    );
  }

  /// `focusedDay` must lie inside [firstDay, lastDay]: the selected day when it is in the focused month,
  /// else the first of the month, never after today.
  DateTime _focused(DateTime today) {
    final m = focusedMonth;
    final sel = selected;
    final f = (sel.year == m.year && sel.month == m.month) ? sel : m;
    return f.isAfter(today) ? today : f;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool hollow;
  const _Legend({required this.color, required this.label, this.hollow = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: hollow ? Colors.transparent : color, shape: BoxShape.circle, border: Border.all(color: color, width: 1.6))),
        const SizedBox(width: EmSpacing.s4),
        Flexible(child: Text(label, style: EmType.caption.copyWith(color: EmColors.textSecondary))),
      ]);
}
