import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/hero_card.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/attendance_controller.dart';
import 'widgets/attendance_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Attendance', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
      header: [
        ScreenHeader(title: 'Attendance', caption: '${cls.label} · ${longDateOf(c.today)}'),
      ],
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
        return [
          HeroCard(
            kicker: 'Class teacher · ${cls.label}',
            value: '$marked / $total',
            trend: trend,
            trendWarn: marked < total,
            percent: total == 0 ? 0 : ((marked / total) * 100).round(),
            metrics: [('$total', 'Students'), ('${counts.present + counts.late}', 'Here'), ('${counts.absent}', 'Absent')],
          ),
          const SizedBox(height: 12),
          if (marked > 0) ...[StatusCountPills(counts: counts), const SizedBox(height: 12)],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('hub_mark_button'),
              onPressed: () => Get.toNamed(Routes.attendanceMark),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: CustomText(text: marked == 0 ? "Mark today's attendance" : "Edit today's attendance", color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('hub_history_button'),
              onPressed: () => Get.toNamed(Routes.attendanceHistory),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const CustomText(text: 'Attendance history', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
            ),
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
