import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart' show AppCard, AppEmptyView, AppErrorView, AppTag, RefreshFailedBanner;
import '../../../../core/widgets/screen_state_view.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/leave_controller.dart';
import '../../../../core/design/design.dart';

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

final TextStyle _quiet = EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.4);

String _n(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// My leave (`/leave`): balance cards and request history.
class LeaveScreen extends GetView<LeaveController> {
  const LeaveScreen({super.key});

  LeaveController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      extendBody: false,
      appBar: EmAppBar(title: 'My leave'),
      // A bottom bar instead of a floating button: a floating button covered the right edge (status chip) of the last visible card (7b review).
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: EmPrimaryButton(key: const Key('leave_apply'), label: 'Apply for leave', icon: Icons.add_rounded, onPressed: () => Get.toNamed(Routes.leaveApply)),
        ),
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
            padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
            children: [
              const SubHeading('Balance'),
              _balance(),
              const SizedBox(height: EmSpacing.s8),
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
        if (st.isStale) return Column(children: [RefreshFailedBanner(message: st.message, onRetry: () => c.loadBalance(userInitiated: true)), _balanceCards(st.data!)]);
        return AppErrorView(key: const Key('leave_balance_error'), message: st.message ?? 'Something went wrong', onRetry: () => c.loadBalance(userInitiated: true));
      case SectionStatus.forbidden:
        return const AppEmptyView(key: Key('leave_balance_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access");
      case SectionStatus.unavailable:
        return const AppEmptyView(key: Key('leave_balance_unavailable'), icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
      case SectionStatus.empty:
        return const SizedBox.shrink();
      case SectionStatus.data:
        return _balanceCards(st.data!);
    }
  }

  Widget _balanceCards(LeaveBalanceSummary b) {
    if (!b.hasPolicy) {
      return AppCard(key: const Key('leave_no_policy'), child: Text('No leave allowance has been set up for you yet, so there is no balance to show. You can still apply: the school decides. Ask HR if this looks wrong.', style: _quiet));
    }
    final shown = b.shown;
    if (shown.isEmpty) return AppCard(key: const Key('leave_no_balance'), child: Text('Your leave allowance shows no days yet.', style: _quiet));
    return Wrap(spacing: EmSpacing.row, runSpacing: EmSpacing.row, children: [for (final k in shown) _BalanceCard(bucket: k)]);
  }

  Widget _history() {
    final st = c.history.value;
    switch (st.status) {
      case SectionStatus.loading:
        return AppShimmer(key: const Key('leave_history_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())));
      case SectionStatus.error:
        if (st.isStale) return Column(children: [RefreshFailedBanner(message: st.message, onRetry: () => c.loadHistory(userInitiated: true)), for (final l in st.data!) _RequestCard(request: l)]);
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
    final w = (MediaQuery.of(context).size.width - EmSpacing.screenH * 2 - EmSpacing.row) / 2;
    final low = bucket.remaining <= 0;
    return SizedBox(
      width: w,
      child: AppCard(
        key: ValueKey('leave_bal_${bucket.type.wire}'),
        margin: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bucket.type.label, style: EmType.caption.copyWith(fontWeight: FontWeight.w800, color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          // none left = an alert glyph next to the number, not only the error colour
          Row(children: [
            if (low) const Padding(padding: EdgeInsetsDirectional.only(end: EmSpacing.s4), child: Icon(Icons.error_outline_rounded, size: 20, color: EmColors.error)),
            Flexible(child: Text(_n(bucket.remaining), style: EmType.title.copyWith(fontWeight: FontWeight.w800, color: low ? EmColors.error : EmColors.primary))),
          ]),
          Text('days left', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          Text('${_n(bucket.used)} used of ${_n(bucket.entitled)}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
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
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${l.typeLabel} leave', style: EmType.body.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag(l.status.label.toUpperCase(), style: leaveStatusTag(l.status)),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text(leaveRange(l), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
        if (l.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(l.reason, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
        if (l.status != StaffLeaveStatus.pending && (l.approverName.isNotEmpty || note.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8),
            child: Text(
              [if (l.approverName.isNotEmpty) '${l.status == StaffLeaveStatus.rejected ? 'Decided' : 'Decision'} by ${l.approverName}', if (note.isNotEmpty) '"$note"'].join(': '),
              key: ValueKey('leave_note_${l.id}'),
              style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ),
      ]),
    );
  }
}
