import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/student_leave_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/message_time.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/custom_text.dart';
import '../../../common/action_failure.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/student_leaves_controller.dart';
import 'student_leaves_screen.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: Obx(() {
        if (!c.allowed) {
          return const AppEmptyView(key: Key('leaves_not_allowed'), icon: Icons.lock_outline_rounded, title: 'Class teachers only');
        }
        final l = c.find(id);
        if (l == null) {
          if (_resolving) return AppShimmer(key: const Key('leave_detail_loading'), child: Column(children: List.generate(3, (_) => const ShimmerListRowSkeleton())));
          return AppEmptyView(key: const Key('leave_not_found'), icon: Icons.event_busy_outlined, title: 'Request not found', subtitle: 'It is not in your class list, or it was removed.');
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          if (conflictText != null) ErrorBanner(bannerKey: const Key('leave_conflict'), message: '$conflictText ${_decidedBy(l)}'.trim()),
          AppCard(
            key: const Key('leave_detail'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: CustomText(text: l.studentName.isEmpty ? 'Student' : l.studentName, fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primaryColor)),
                AppTag(l.status.label, style: leaveStatusStyle(l.status)),
              ]),
              const SizedBox(height: 10),
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
                CustomText(text: _decidedBy(l).isEmpty ? l.status.label : _decidedBy(l), fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryColor),
                if (l.approverNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: 'Remarks: ${l.approverNote}', fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          if (l.isPending) ...[
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: OutlinedButton(key: const Key('leave_reject'), onPressed: () => _review(l, LeaveStatus.rejected), child: const CustomText(text: 'Reject', color: AppColors.redText, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(key: const Key('leave_approve'), onPressed: () => _review(l, LeaveStatus.approved), child: const CustomText(text: 'Approve', color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            const CustomText(text: "The parent is notified in their app as soon as you decide.", fontSize: 11, color: AppColors.muted, textAlign: TextAlign.center),
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: CustomText(text: k, fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w800)),
          Expanded(child: CustomText(text: v, fontSize: 13, color: AppColors.ink)),
        ]),
      );

  Future<void> _review(StudentLeaveRequest l, LeaveStatus decision) async {
    final result = await showModalBottomSheet<ReviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ReviewSheet(leave: l, decision: decision, controller: c),
    );
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(key: const Key('review_title'), text: approve ? 'Approve this leave request?' : 'Reject this leave request?', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          const SizedBox(height: 4),
          CustomText(text: '${widget.leave.studentName} · ${leaveRangeText(widget.leave)}', fontSize: 12, color: AppColors.muted),
          const SizedBox(height: 12),
          if (error != null) ErrorBanner(bannerKey: const Key('review_error'), message: error!),
          TextField(
            key: const Key('review_remarks'),
            controller: remarks,
            maxLines: 3,
            minLines: 2,
            maxLength: kLeaveRemarksMax,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Remarks for the parent (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final busy = widget.controller.reviewing.value != null;
            return Row(children: [
              Expanded(child: OutlinedButton(key: const Key('review_cancel'), onPressed: busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('review_confirm'),
                  style: approve ? null : ElevatedButton.styleFrom(backgroundColor: AppColors.redText),
                  onPressed: busy ? null : _confirm,
                  child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : CustomText(text: approve ? 'Approve' : 'Reject', color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ]);
          }),
        ]),
      ),
    );
  }
}
