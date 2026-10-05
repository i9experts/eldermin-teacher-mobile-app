import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/models/classroom/attendance_month.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/attendance_controller.dart' show kAttendanceEditWindowDays;
import '../controllers/attendance_history_controller.dart';
import 'widgets/attendance_widgets.dart';

/// Attendance history (`/attendance/history`): a month calendar with a coloured marker on every day that
/// has records, the per-day summary counts, and a day detail with an "Edit" shortcut where editing is allowed
/// (today and the previous [kAttendanceEditWindowDays] days; older days are read-only).
class AttendanceHistoryScreen extends GetView<AttendanceHistoryController> {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Attendance history', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
        ScreenHeader(title: 'History', caption: cls.label),
        _Calendar(controller: c, month: s.data, selected: selected, focusedMonth: focused),
        const SizedBox(height: 12),
      ],
      builder: (m) => _detail(m, selected, roster, editable),
    );
  }

  List<Widget> _detail(MonthAttendance m, DateTime d, List<StudentSummary> roster, bool editable) {
    final c = controller;
    final day = m.day(ymdOf(d));
    final title = '${longDateOf(d)}${sameSelected(d, c.today) ? ' · Today' : ''}';
    return [
      SubHeading(title),
      if (day == null)
        AppCard(
          key: const Key('history_day_empty'),
          child: Row(children: [
            const Icon(Icons.event_busy_outlined, color: AppColors.faint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: CustomText(
                text: d.isAfter(c.today) ? 'This day is in the future.' : 'No attendance was recorded for this day.',
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ]),
        )
      else
        AppCard(
          key: const Key('history_day_card'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(
              text: 'Marked ${day.marked} of ${m.rosterSize}${day.complete ? '' : ' (incomplete)'}',
              color: day.complete ? AppColors.green : AppColors.amberText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            const SizedBox(height: 8),
            StatusCountPills(counts: day.counts, showZero: true),
            ..._notPresent(day, roster),
          ]),
        ),
      if (!d.isAfter(c.today)) ...[
        const SizedBox(height: 4),
        if (editable)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('history_edit_button'),
              onPressed: () => Get.toNamed('${Routes.attendanceMark}?date=${ymdOf(d)}'),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: CustomText(text: day == null ? 'Mark this day' : 'Edit this day', color: Colors.white, fontWeight: FontWeight.w700),
            ),
          )
        else
          CustomText(
            key: const Key('history_read_only'),
            text: 'Older than $kAttendanceEditWindowDays days: view only.',
            color: AppColors.faint,
            fontSize: 11,
          ),
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
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 62, child: CustomText(text: st.label, color: statusColors(st).fg, fontWeight: FontWeight.w800, fontSize: 11)),
          Expanded(child: CustomText(text: names.join(', '), color: AppColors.ink, fontSize: 12)),
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
        return AppColors.green;
      case DayTone.attention:
        return AppColors.amber;
      case DayTone.absences:
        return AppColors.red;
      case DayTone.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final today = c.today;
    return Container(
      key: const Key('history_calendar'),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
      child: Column(children: [
        TableCalendar<void>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(today.year, today.month, today.day),
          focusedDay: _focused(today),
          selectedDayPredicate: (d) => isSameDay(d, selected),
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: AppColors.pale, shape: BoxShape.circle, border: Border.all(color: AppColors.blue)),
            todayTextStyle: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700),
            selectedDecoration: const BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
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
                bottom: 4,
                child: Container(
                  key: ValueKey('marker_${ymdOf(day)}'),
                  width: 7,
                  height: 7,
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
          padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _Legend(color: AppColors.green, label: 'All present'),
            _Legend(color: AppColors.amber, label: 'Late / leave'),
            _Legend(color: AppColors.red, label: 'Absences'),
            _Legend(color: AppColors.faint, label: 'Hollow = not everyone marked', hollow: true),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: hollow ? Colors.transparent : color, shape: BoxShape.circle, border: Border.all(color: color, width: 1.6))),
        const SizedBox(width: 5),
        CustomText(text: label, color: AppColors.muted, fontSize: 10),
      ]);
}
