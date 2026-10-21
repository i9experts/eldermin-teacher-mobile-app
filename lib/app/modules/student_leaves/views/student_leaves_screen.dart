import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/student_leave_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/student_leaves_controller.dart';
import '../../../../core/design/design.dart';

/// Student leave requests of my class (`/student-leaves`): Pending / Approved / Rejected tabs. Class teachers only.
class StudentLeavesScreen extends GetView<StudentLeavesController> {
  const StudentLeavesScreen({super.key});

  StudentLeavesController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Student leave requests'),
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
            EmSegmentedTabs<LeaveStatus>(
              key: const Key('leaves_tabs'),
              segments: [for (final s in LeaveStatus.values) EmSegment(s, _tabLabel(s))],
              selected: tab,
              onChanged: c.selectTab,
            ),
            const SizedBox(height: EmSpacing.row),
          ],
          builder: (rows) => [
            for (final l in rows) LeaveCard(leave: l, onTap: () => Get.toNamed(Routes.studentLeaveDetailOf(l.id))),
            if (rows.length >= StudentLeavesController.listLimit)
              Text('Showing the most recent 100 requests.', key: const Key('leaves_cut'), textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
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

EmTone leaveStatusStyle(LeaveStatus s) => switch (s) {
      LeaveStatus.pending => EmTone.warning,
      LeaveStatus.approved => EmTone.success,
      LeaveStatus.rejected => EmTone.error,
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
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(l.studentName.isEmpty ? 'Student' : l.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag(l.status.label, style: leaveStatusStyle(l.status)),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text(leaveRangeText(l), style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
        if (l.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(l.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
        const SizedBox(height: EmSpacing.s8),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppTag(l.typeLabel, style: EmTone.info),
          if (l.requestedByName.isNotEmpty) Text('Requested by ${l.requestedByName}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
      ]),
    );
  }
}
