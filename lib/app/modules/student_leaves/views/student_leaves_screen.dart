import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/student_leave_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/student_leaves_controller.dart';

/// Student leave requests of my class (`/student-leaves`): Pending / Approved / Rejected tabs. Class teachers only.
class StudentLeavesScreen extends GetView<StudentLeavesController> {
  const StudentLeavesScreen({super.key});

  StudentLeavesController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student leave requests')),
      body: Obx(() {
        if (!c.allowed) {
          return const AppEmptyView(key: Key('leaves_not_allowed'), icon: Icons.lock_outline_rounded, title: 'Class teachers only', subtitle: 'Only the class teacher can review the leave requests of their class.');
        }
        final tab = c.tab.value;
        var st = c.stateOf(tab);
        return ScreenStateView<List<StudentLeaveRequest>>(
          state: st,
          onRefresh: c.reload,
          onRetry: () => c.loadTab(tab, userInitiated: true),
          emptyIcon: Icons.event_available_outlined,
          emptyTitle: switch (tab) {
            LeaveStatus.pending => 'No pending requests',
            LeaveStatus.approved => 'No approved requests',
            LeaveStatus.rejected => 'No rejected requests',
          },
          emptySubtitle: tab == LeaveStatus.pending ? 'New requests from parents appear here.' : null,
          header: [
            SegmentedControl(
              key: const Key('leaves_tabs'),
              options: [for (final s in LeaveStatus.values) _tabLabel(s)],
              selectedIndex: tab.index,
              onChanged: (i) => c.selectTab(LeaveStatus.values[i]),
            ),
            const SizedBox(height: 12),
          ],
          builder: (rows) => [
            for (final l in rows) LeaveCard(leave: l, onTap: () => Get.toNamed(Routes.studentLeaveDetailOf(l.id))),
            if (rows.length >= StudentLeavesController.listLimit)
              const CustomText(key: Key('leaves_cut'), text: 'Showing the most recent 100 requests.', fontSize: 11, color: AppColors.muted, textAlign: TextAlign.center),
          ],
        );
      }),
    );
  }

  String _tabLabel(LeaveStatus s) {
    final n = c.countOf(s);
    return n == null ? s.label : '${s.label} ($n${s == LeaveStatus.pending && c.pendingMayBeCut ? '+' : ''})';
  }
}

/// "Mon 5 Oct - Wed 7 Oct (3 days)".
String leaveRangeText(StudentLeaveRequest l) {
  final a = l.firstDay, b = l.lastDay;
  if (a == null) return 'Dates not given';
  final same = b == null || (a.year == b.year && a.month == b.month && a.day == b.day);
  final days = l.days;
  final range = same ? shortDay(a) : '${shortDay(a)} - ${shortDay(b)}';
  return days == null || days == 1 ? range : '$range ($days days)';
}

TagStyle leaveStatusStyle(LeaveStatus s) => switch (s) {
      LeaveStatus.pending => TagStyle.amber,
      LeaveStatus.approved => TagStyle.green,
      LeaveStatus.rejected => TagStyle.red,
    };

class LeaveCard extends StatelessWidget {
  final StudentLeaveRequest leave;
  final VoidCallback onTap;
  const LeaveCard({super.key, required this.leave, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = leave;
    return AppCard(
      key: Key('leave_${l.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: l.studentName.isEmpty ? 'Student' : l.studentName, fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis)),
          AppTag(l.status.label, style: leaveStatusStyle(l.status)),
        ]),
        const SizedBox(height: 4),
        CustomText(text: leaveRangeText(l), fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w700),
        if (l.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: l.reason, fontSize: 12, color: AppColors.muted, maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 6),
        Row(children: [
          AppTag(l.typeLabel, style: TagStyle.info),
          const SizedBox(width: 8),
          if (l.requestedByName.isNotEmpty) Expanded(child: CustomText(text: 'Requested by ${l.requestedByName}', fontSize: 10.5, color: AppColors.faint, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }
}
