import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/attendance_controller.dart';
import 'widgets/attendance_widgets.dart';
import '../../../../core/design/design.dart';

/// Attendance hub (`/attendance` and the Attendance tab of class teachers): today's status for MY
/// class with entry points to mark and to the history. Class teachers only: anyone else gets an
/// honest "not available" page (UI gating; the backend is the security layer).
/// [embedded] renders just the body for the HomeShell tab.
class AttendanceScreen extends GetView<AttendanceController> {
  final bool embedded;
  const AttendanceScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = Obx(() => controller.allowed ? _hub() : const _NotClassTeacher());
    if (embedded) return body;
    return EmScaffold(
      appBar: EmAppBar(title: 'Attendance'),
      body: body,
    );
  }

  Widget _hub() {
    final c = controller;
    final cls = c.myClass!;
    // Read every reactive value HERE (inside the Obx); the builder below runs later, outside its tracking.
    final marked = c.markedCount;
    final counts = c.counts;
    final day = c.day.value;
    return ScreenStateView<List<StudentSummary>>(
      state: c.roster.value,
      onRefresh: c.reload,
      onRetry: c.retry,
      emptyIcon: Icons.groups_outlined,
      emptyTitle: 'No students in your class',
      emptySubtitle: 'There are no active students in ${cls.label} yet.',
      header: [EmCaptionLine('${cls.label} · ${longDateOf(c.today)}')],
      builder: (roster) {
        final total = roster.length;
        final isToday = sameDate(day, c.today);
        final String trend;
        if (!isToday) {
          trend = 'Viewing ${longDateOf(day)}';
        } else if (marked == 0) {
          trend = "Attendance isn't marked yet today";
        } else if (marked < total) {
          trend = 'Partly marked today';
        } else {
          trend = 'Attendance marked today';
        }
        final percent = total == 0 ? 0 : ((marked / total) * 100).round();
        return [
          EmHeroCard(
            padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Class teacher · ${cls.label}', maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary)),
              const SizedBox(height: EmSpacing.s8),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('$marked / $total', style: EmType.display.copyWith(color: EmColors.ink)),
                    ),
                    const SizedBox(height: EmSpacing.s8),
                    // status dot + words: the warning is never colour alone
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: EmSpacing.s4),
                        child: Icon(marked < total ? Icons.pending_actions_rounded : Icons.check_circle_rounded, size: 16, color: marked < total ? EmColors.onWarningContainer : EmColors.onSuccessContainer),
                      ),
                      const SizedBox(width: EmSpacing.s8),
                      Expanded(child: Text(trend, style: EmType.body.copyWith(color: EmColors.ink))),
                    ]),
                  ]),
                ),
                const SizedBox(width: EmSpacing.s12),
                EmProgressRing(value: percent / 100, size: 96, strokeWidth: 10, centerText: '$percent%', semanticLabel: 'Marked $percent percent'),
              ]),
              const SizedBox(height: EmSpacing.s16),
              EmStatTileRow(tiles: [
                EmStatTile(icon: Icons.groups_outlined, value: '$total', label: 'Students'),
                EmStatTile(icon: Icons.how_to_reg_outlined, value: '${counts.present + counts.late}', label: 'Here'),
                EmStatTile(icon: Icons.person_off_outlined, value: '${counts.absent}', label: 'Absent'),
              ]),
            ]),
          ),
          const SizedBox(height: EmSpacing.row),
          if (marked > 0) ...[StatusCountPills(counts: counts), const SizedBox(height: EmSpacing.row)],
          EmPrimaryButton(
            key: const Key('hub_mark_button'),
            icon: Icons.fact_check_outlined,
            label: marked == 0 ? "Mark today's attendance" : "Edit today's attendance",
            onPressed: () => Get.toNamed(Routes.attendanceMark),
          ),
          const SizedBox(height: EmSpacing.s8),
          EmSecondaryButton(
            key: const Key('hub_history_button'),
            expand: true,
            icon: Icons.calendar_month_rounded,
            label: 'Attendance history',
            onPressed: () => Get.toNamed(Routes.attendanceHistory),
          ),
        ];
      },
    );
  }
}

class _NotClassTeacher extends StatelessWidget {
  const _NotClassTeacher();

  @override
  Widget build(BuildContext context) => const AppEmptyView(
        key: Key('attendance_not_class_teacher'),
        icon: Icons.lock_outline_rounded,
        title: 'Attendance is for class teachers',
        subtitle: 'Only the class teacher of a class marks its daily attendance. Ask your school admin if this should be you.',
      );
}
