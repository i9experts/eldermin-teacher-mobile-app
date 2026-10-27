import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/models/json_helpers.dart' show wireDay;
import '../../../../core/services/self_attendance_repository.dart' show kNoStaffRecordMessage;
import '../../../../core/utils/self_attendance_rules.dart' show MonthSummary;
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/my_attendance_controller.dart';
import 'my_attendance_format.dart';
import 'my_attendance_sheets.dart';

/// My attendance (`/my-attendance`): my own days of one month (with a summary) and my correction requests.
class MyAttendanceScreen extends GetView<MyAttendanceController> {
  const MyAttendanceScreen({super.key});

  MyAttendanceController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      extendBody: false,
      appBar: EmAppBar(title: 'My attendance'),
      // A day with no record (a missed punch) cannot be tapped, so the form is also reachable from here.
      bottomNavigationBar: Obx(() => c.noStaffRecord.value
          ? const SizedBox.shrink()
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
                decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
                child: EmPrimaryButton(
                    key: const Key('my_att_new_correction'),
                    label: 'Request a correction',
                    icon: Icons.edit_calendar_rounded,
                    onPressed: () => openCorrectionForm()),
              ),
            )),
      body: Obx(() {
        if (c.noStaffRecord.value) return _noStaff();
        final tab = c.tab.value;
        final tabs = EmSegmentedTabs<MyAttendanceTab>(
          key: const Key('my_att_tabs'),
          segments: const [EmSegment(MyAttendanceTab.attendance, 'Attendance'), EmSegment(MyAttendanceTab.requests, 'Requests')],
          selected: tab,
          onChanged: c.setTab,
        );
        if (tab == MyAttendanceTab.requests) {
          return ScreenStateView<List<AttendanceCorrectionRequest>>(
            state: c.requests.value,
            onRefresh: () => c.reload(userInitiated: true),
            onRetry: () => c.loadRequests(userInitiated: true),
            header: [tabs, const SizedBox(height: EmSpacing.s12)],
            emptyIcon: Icons.edit_calendar_outlined,
            emptyTitle: 'No correction requests yet',
            emptySubtitle: 'Open a day in Attendance and choose Request correction. Requests you send appear here with their decision.',
            builder: (rows) => [for (final r in rows) _RequestRow(request: r)],
          );
        }
        final m = c.month.value;
        final st = c.days.value;
        return ScreenStateView<List<StaffAttendanceDay>>(
          state: st,
          onRefresh: () => c.reload(userInitiated: true),
          onRetry: () => c.loadDays(userInitiated: true),
          header: [
            tabs,
            const SizedBox(height: EmSpacing.s12),
            _MonthBar(c: c),
            const SizedBox(height: EmSpacing.s12),
            if (st.hasData) ...[_Summary(summary: c.summary), const SizedBox(height: EmSpacing.s12)]
          ],
          emptyIcon: Icons.event_busy_outlined,
          emptyTitle: 'No attendance records for ${monthTitle(m)}',
          emptySubtitle: 'Days appear here once they are recorded. Pull down to refresh.',
          builder: (rows) => [for (final d in rows) _DayRow(day: d, pending: d.day == null ? null : c.pendingFor(d.day!))],
        );
      }),
    );
  }

  Widget _noStaff() => RefreshIndicator(
        onRefresh: () => c.reload(userInitiated: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EmSpacing.listPadding,
          children: const [
            EmEmptyState(
              key: Key('my_att_no_staff'),
              icon: Icons.person_off_outlined,
              title: 'No staff record linked',
              message: kNoStaffRecordMessage,
              scroll: false,
            ),
          ],
        ),
      );
}

class _MonthBar extends StatelessWidget {
  final MyAttendanceController c;
  const _MonthBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = c.month.value;
      final canNext = c.canGoNext;
      return Row(children: [
        EmIconCircleButton(
            key: const Key('my_att_prev'),
            icon: Icons.chevron_left_rounded,
            semanticLabel: 'Previous month',
            tooltip: 'Previous month',
            elevated: false,
            onTap: c.previousMonth),
        Expanded(
          child: InkWell(
            key: const Key('my_att_month'),
            borderRadius: EmRadius.mdAll,
            onTap: () async {
              final now = c.today;
              final picked = await showAppMonthPicker(context, initialMonth: m, maxMonth: DateTime(now.year, now.month));
              if (picked != null) c.setMonth(picked);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
              child: Center(child: Text(monthTitle(m), textAlign: TextAlign.center, style: EmType.heading.copyWith(color: EmColors.ink))),
            ),
          ),
        ),
        EmIconCircleButton(
          key: const Key('my_att_next'),
          icon: Icons.chevron_right_rounded,
          semanticLabel: canNext ? 'Next month' : 'Next month, not available',
          tooltip: 'Next month',
          elevated: false,
          iconColor: canNext ? EmColors.ink : EmColors.textTertiary,
          onTap: canNext ? c.nextMonth : null,
        ),
      ]);
    });
  }
}

class _Summary extends StatelessWidget {
  final MonthSummary summary;
  const _Summary({required this.summary});

  @override
  Widget build(BuildContext context) => EmHeroCard(
        key: const Key('my_att_summary'),
        padding: const EdgeInsetsDirectional.all(EmSpacing.s12),
        child: EmStatTileRow(tiles: [
          EmStatTile(icon: Icons.check_circle_outline_rounded, value: '${summary.present}', label: 'Present'),
          EmStatTile(icon: Icons.schedule_rounded, value: '${summary.late}', label: 'Late'),
          EmStatTile(icon: Icons.person_off_outlined, value: '${summary.absent}', label: 'Absent'),
          EmStatTile(icon: Icons.beach_access_outlined, value: '${summary.leave}', label: 'Leave'),
        ]),
      );
}

class _DayRow extends StatelessWidget {
  final StaffAttendanceDay day;
  final AttendanceCorrectionRequest? pending;
  const _DayRow({required this.day, this.pending});

  @override
  Widget build(BuildContext context) {
    final sub =
        [timesText(day.checkIn, day.checkOut), lateText(day.lateByMins), if (pending != null) 'Correction pending'].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmListRow(
        key: ValueKey('my_att_day_${day.id}'),
        icon: Icons.event_note_rounded,
        title: dayText(day.day),
        subtitle: sub.isEmpty ? null : sub,
        trailing: Flexible(child: EmChip.status(label: day.statusLabel, tone: dayStatusTone(day.status))),
        onTap: () => showAttendanceDaySheet(context, day, pending: pending),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final AttendanceCorrectionRequest request;
  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmListRow(
        key: ValueKey('my_att_req_${r.id}'),
        icon: Icons.edit_calendar_rounded,
        title: dayText(r.day),
        subtitle: '${r.currentLabel} to ${r.requestedLabel}',
        trailing: Flexible(child: EmChip.status(label: r.status.label, tone: correctionTone(r.status))),
        onTap: () => showCorrectionSheet(context, r),
      ),
    );
  }
}

/// Opens the correction form for [date] (null = the form asks for it).
void openCorrectionForm({DateTime? date}) => Get.toNamed(Routes.myAttendanceCorrect, arguments: date == null ? null : {'date': wireDay(date)});
