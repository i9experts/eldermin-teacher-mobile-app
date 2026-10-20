import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/student_leave_models.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../common/action_failure.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/student_leaves_controller.dart';
import 'student_leaves_screen.dart';
import '../../../../core/design/design.dart';

/// One leave request (`/student-leaves/:id`): details + approve / reject (confirm sheet with optional remarks).
/// There is no "get one" endpoint, so the request is found in the lists the controller loads.
class StudentLeaveDetailScreen extends StatefulWidget {
  final String? leaveId;
  const StudentLeaveDetailScreen({super.key, this.leaveId});
  @override
  State<StudentLeaveDetailScreen> createState() => _State();
}

class _State extends State<StudentLeaveDetailScreen> {
  late final String id = widget.leaveId ?? Get.parameters['id'] ?? '';
  StudentLeavesController get c => Get.find<StudentLeavesController>();
  bool _resolving = true;

  /// Set after a 409: the server's text; the card then shows who decided and when.
  String? conflictText;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    await c.resolve(id);
    if (mounted) setState(() => _resolving = false);
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Leave request'),
      body: Obx(() {
        if (!c.allowed) {
          return const AppEmptyView(key: Key('leaves_not_allowed'), icon: Icons.lock_outline_rounded, title: 'Class teachers only');
        }
        final l = c.find(id);
        if (l == null) {
          if (_resolving) return AppShimmer(key: const Key('leave_detail_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())));
          return AppEmptyView(key: const Key('leave_not_found'), icon: Icons.event_busy_outlined, title: 'Request not found', subtitle: 'It is not in your class list, or it was removed.');
        }
        return ListView(padding: EmSpacing.listPadding, children: [
          if (conflictText != null) ErrorBanner(bannerKey: const Key('leave_conflict'), message: '$conflictText ${_decidedBy(l)}'.trim()),
          AppCard(
            key: const Key('leave_detail'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(l.studentName.isEmpty ? 'Student' : l.studentName, style: EmType.heading.copyWith(color: EmColors.ink))),
                const SizedBox(width: EmSpacing.s8),
                AppTag(l.status.label, style: leaveStatusStyle(l.status)),
              ]),
              const SizedBox(height: EmSpacing.row),
              _kv('Dates', leaveRangeText(l)),
              _kv('Type', l.typeLabel),
              _kv('Reason', l.reason.isEmpty ? 'No reason given' : l.reason),
              _kv('Requested by', l.requestedByName.isEmpty ? 'Guardian' : l.requestedByName),
              if (l.createdAt != null) _kv('Requested', '${relativeTime(DateTime.now(), l.createdAt!)} · ${absoluteTime(l.createdAt!)}'),
            ]),
          ),
          if (!l.isPending)
            AppCard(
              key: const Key('leave_decided'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_decidedBy(l).isEmpty ? l.status.label : _decidedBy(l), style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                if (l.approverNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('Remarks: ${l.approverNote}', style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
              ]),
            ),
          if (l.isPending) ...[
            const SizedBox(height: EmSpacing.s4),
            Row(children: [
              Expanded(child: EmSecondaryButton(key: const Key('leave_reject'), expand: true, destructive: true, label: 'Reject', onPressed: () => _review(l, LeaveStatus.rejected))),
              const SizedBox(width: EmSpacing.row),
              Expanded(child: EmPrimaryButton(key: const Key('leave_approve'), label: 'Approve', onPressed: () => _review(l, LeaveStatus.approved))),
            ]),
            const SizedBox(height: EmSpacing.row),
            Text('The parent is notified in their app as soon as you decide.', textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ],
        ]);
      }),
    );
  }

  String _decidedBy(StudentLeaveRequest l) {
    if (l.isPending) return '';
    final who = l.approverName.isEmpty ? '' : ' by ${l.approverName}';
    final at = l.decidedAt == null ? '' : ' on ${absoluteTime(l.decidedAt!)}';
    return '${l.status.label}$who$at.';
  }

  /// Label above its value: no fixed-width label column, so a long value or a large text scale never squeezes either.
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(v, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
        ]),
      );

  Future<void> _review(StudentLeaveRequest l, LeaveStatus decision) async {
    final result = await EmBottomSheet.showPanel<ReviewResult>(context, builder: (_) => ReviewSheet(leave: l, decision: decision, controller: c));
    if (!mounted || result == null) return;
    if (result is ReviewConflict) setState(() => conflictText = result.serverText);
    if (result is ReviewDone) {
      setState(() => conflictText = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request ${result.leave.status.wire}. The parent has been notified.')));
    }
  }
}

/// Confirm sheet: what will happen, optional remarks (max [kLeaveRemarksMax]), Confirm / Cancel. Pops with the [ReviewResult] on done / conflict.
class ReviewSheet extends StatefulWidget {
  final StudentLeaveRequest leave;
  final LeaveStatus decision;
  final StudentLeavesController controller;
  const ReviewSheet({super.key, required this.leave, required this.decision, required this.controller});
  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  final remarks = TextEditingController();
  String? error;

  @override
  void dispose() {
    remarks.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final r = await widget.controller.review(widget.leave.id, widget.decision, remarks: remarks.text);
    if (!mounted) return;
    switch (r) {
      case ReviewDone() || ReviewConflict():
        Navigator.of(context).pop(r);
      case ReviewFailed(:final failure):
        setState(() => error = failure.kind == ActionFailureKind.forbidden && failure.serverMessage.isNotEmpty ? failure.serverMessage : failure.message);
      case ReviewIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.decision == LeaveStatus.approved;
    return Padding(
      padding: EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(approve ? 'Approve this leave request?' : 'Reject this leave request?', key: const Key('review_title'), style: EmType.heading.copyWith(color: EmColors.ink)),
            const SizedBox(height: EmSpacing.s4),
            Text('${widget.leave.studentName} · ${leaveRangeText(widget.leave)}', style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
            const SizedBox(height: EmSpacing.block),
            if (error != null) ErrorBanner(bannerKey: const Key('review_error'), message: error!),
            TextField(
              key: const Key('review_remarks'),
              controller: remarks,
              maxLines: 3,
              minLines: 2,
              maxLength: kLeaveRemarksMax,
              textCapitalization: TextCapitalization.sentences,
              style: EmType.body.copyWith(color: EmColors.ink),
              decoration: const InputDecoration(labelText: 'Remarks for the parent (optional)'),
            ),
            const SizedBox(height: EmSpacing.s8),
            Obx(() {
              final busy = widget.controller.reviewing.value != null;
              return Row(children: [
                Expanded(child: EmSecondaryButton(key: const Key('review_cancel'), expand: true, label: 'Cancel', onPressed: busy ? null : () => Navigator.of(context).pop())),
                const SizedBox(width: EmSpacing.row),
                Expanded(child: EmPrimaryButton(key: const Key('review_confirm'), destructive: !approve, loading: busy, label: approve ? 'Approve' : 'Reject', onPressed: busy ? null : _confirm)),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}
