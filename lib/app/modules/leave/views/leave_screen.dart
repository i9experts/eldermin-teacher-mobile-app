import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/leave_controller.dart';

TagStyle leaveStatusTag(StaffLeaveStatus s) => switch (s) {
      StaffLeaveStatus.pending => TagStyle.amber,
      StaffLeaveStatus.approved => TagStyle.green,
      StaffLeaveStatus.rejected => TagStyle.red,
      StaffLeaveStatus.cancelled => TagStyle.neutral,
      StaffLeaveStatus.onHold => TagStyle.info,
      StaffLeaveStatus.unknown => TagStyle.neutral,
    };

String leaveRange(StaffLeaveRequest l) {
  final a = l.firstDay, b = l.lastDay;
  if (a == null) return 'Dates not given';
  final same = b == null || (a.year == b.year && a.month == b.month && a.day == b.day);
  final range = same ? '${shortDay(a)} ${a.year}' : '${shortDay(a)} - ${shortDay(b)} ${b.year}';
  final days = l.isHalfDay ? 'half day${l.halfDaySession.isEmpty ? '' : ', ${l.halfDaySession}'}' : (l.totalDays == null ? null : '${_n(l.totalDays!)} ${l.totalDays == 1 ? 'day' : 'days'}');
  return days == null ? range : '$range ($days)';
}

String _n(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// My leave (`/leave`): balance cards and request history.
class LeaveScreen extends GetView<LeaveController> {
  const LeaveScreen({super.key});

  LeaveController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My leave')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('leave_apply'),
        onPressed: () => Get.toNamed(Routes.leaveApply),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply for leave'),
      ),
      body: Obx(() {
        final whole = c.wholeScreenStatus;
        if (whole != null) {
          // Same message for both sections: show it once (still pull-to-refresh).
          return ScreenStateView<void>(state: c.balance.value as SectionState<void>, onRefresh: () => c.reload(userInitiated: true), onRetry: () => c.reload(userInitiated: true), builder: (_) => const []);
        }
        return RefreshIndicator(
          onRefresh: () => c.reload(userInitiated: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              const SubHeading('Balance'),
              _balance(),
              const SizedBox(height: 8),
              const SubHeading('My requests'),
              _history(),
            ],
          ),
        );
      }),
    );
  }

  Widget _balance() {
    final st = c.balance.value;
    switch (st.status) {
      case SectionStatus.loading:
        return const AppShimmer(key: Key('leave_balance_loading'), child: ShimmerListRowSkeleton());
      case SectionStatus.error:
        return AppErrorView(key: const Key('leave_balance_error'), message: st.message ?? 'Something went wrong', onRetry: () => c.loadBalance(userInitiated: true));
      case SectionStatus.forbidden:
        return const AppEmptyView(key: Key('leave_balance_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access");
      case SectionStatus.unavailable:
        return const AppEmptyView(key: Key('leave_balance_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
      case SectionStatus.empty:
        return const SizedBox.shrink();
      case SectionStatus.data:
        final b = st.data!;
        if (!b.hasPolicy) {
          return const AppCard(key: Key('leave_no_policy'), child: CustomText(text: 'No leave allowance has been set up for you yet, so there is no balance to show. You can still apply: the school decides. Ask HR if this looks wrong.', fontSize: 12.5, color: AppColors.muted, height: 1.4));
        }
        final shown = b.shown;
        if (shown.isEmpty) return const AppCard(key: Key('leave_no_balance'), child: CustomText(text: 'Your leave allowance shows no days yet.', fontSize: 12.5, color: AppColors.muted));
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final k in shown) _BalanceCard(bucket: k)]);
    }
  }

  Widget _history() {
    final st = c.history.value;
    switch (st.status) {
      case SectionStatus.loading:
        return AppShimmer(key: const Key('leave_history_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())));
      case SectionStatus.error:
        return AppErrorView(key: const Key('leave_history_error'), message: st.message ?? 'Something went wrong', onRetry: () => c.loadHistory(userInitiated: true));
      case SectionStatus.forbidden:
        return const AppEmptyView(key: Key('leave_history_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access");
      case SectionStatus.unavailable:
        return const AppEmptyView(key: Key('leave_history_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
      case SectionStatus.empty:
        return const AppEmptyView(key: Key('leave_history_empty'), icon: Icons.beach_access_outlined, title: 'No leave requests yet', subtitle: 'Requests you send appear here with their decision.');
      case SectionStatus.data:
        return Column(children: [for (final l in st.data!) _RequestCard(request: l)]);
    }
  }
}

class _BalanceCard extends StatelessWidget {
  final LeaveBucket bucket;
  const _BalanceCard({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    final low = bucket.remaining <= 0;
    return SizedBox(
      width: w,
      child: AppCard(
        key: ValueKey('leave_bal_${bucket.type.wire}'),
        margin: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(text: bucket.type.label, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted),
          const SizedBox(height: 4),
          CustomText(text: _n(bucket.remaining), fontSize: 26, fontWeight: FontWeight.w800, color: low ? AppColors.redText : AppColors.primaryColor),
          CustomText(text: 'days left', fontSize: 11, color: AppColors.muted),
          const SizedBox(height: 4),
          CustomText(text: '${_n(bucket.used)} used of ${_n(bucket.entitled)}', fontSize: 11, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final StaffLeaveRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final l = request;
    final note = l.status == StaffLeaveStatus.rejected && l.rejectionReason.isNotEmpty ? l.rejectionReason : l.approverNote;
    return AppCard(
      key: ValueKey('leave_${l.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: '${l.typeLabel} leave', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor)),
          AppTag(l.status.label.toUpperCase(), style: leaveStatusTag(l.status)),
        ]),
        const SizedBox(height: 4),
        CustomText(text: leaveRange(l), fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
        if (l.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: l.reason, fontSize: 12, color: AppColors.muted, height: 1.35)),
        if (l.status != StaffLeaveStatus.pending && (l.approverName.isNotEmpty || note.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: CustomText(
              key: ValueKey('leave_note_${l.id}'),
              text: [if (l.approverName.isNotEmpty) '${l.status == StaffLeaveStatus.rejected ? 'Decided' : 'Decision'} by ${l.approverName}', if (note.isNotEmpty) '"$note"'].join(': '),
              fontSize: 11.5,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
      ]),
    );
  }
}
