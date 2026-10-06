import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show InfoLine;
import '../controllers/lesson_plan_detail_controller.dart';
import '../controllers/lesson_plan_form_controller.dart';
import 'widgets/lesson_plan_widgets.dart';

/// One plan (`/lesson-plans/:id`): all fields, status, the rejection reason (ONLY when rejected) or approver notes (ONLY when approved),
/// and the actions the status allows: submit, edit, edit and resubmit. Approving / rejecting is a coordinator action and is not offered.
class LessonPlanDetailScreen extends GetView<LessonPlanDetailController> {
  const LessonPlanDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Lesson plan', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final c = controller;
        final state = c.state.value;
        final busy = c.submitting.value;
        final failure = c.actionFailure.value;
        return ScreenStateView<LessonPlanRecord>(
          state: state,
          onRefresh: () => c.load(force: true),
          onRetry: () => c.load(force: true),
          emptyTitle: 'Not found',
          builder: (p) => _content(context, p, busy, failure?.message),
        );
      }),
    );
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Widget _section(String title, String text, {Key? k}) => text.trim().isEmpty
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SubHeading(title), AppCard(child: CustomText(key: k, text: text, fontSize: 12.5, height: 1.4))]);

  List<Widget> _content(BuildContext context, LessonPlanRecord p, bool busy, String? failure) {
    final day = p.planDay;
    final reason = p.rejectionReason;
    final notes = p.approverNotes;
    final method = kLessonMethodologies[p.teachingMethodology] ?? p.teachingMethodology;
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: CustomText(key: const Key('lp_topic'), text: p.topic.isEmpty ? '(No topic)' : p.topic, fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor, height: 1.2)),
        const SizedBox(width: 8),
        PlanStatusTag(p.status),
      ]),
      const SizedBox(height: 4),
      CustomText(text: [p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 14),
      if (failure != null) NoteBox(boxKey: const Key('lp_action_error'), icon: Icons.error_outline_rounded, title: failure, fg: AppColors.redText, bg: AppColors.redBg),
      // Shown ONLY for a rejected plan: the server keeps an old reason on a resubmitted one (raw $set, teaching.service.ts:191-207).
      if (p.status == LessonPlanStatus.rejected)
        NoteBox(
          boxKey: const Key('lp_rejection'),
          icon: Icons.cancel_outlined,
          title: 'Rejected by your approver',
          body: reason == null || reason.isEmpty ? 'No reason was given.' : reason,
          fg: AppColors.redText,
          bg: AppColors.redBg,
        ),
      if (p.status == LessonPlanStatus.approved && notes != null && notes.isNotEmpty)
        NoteBox(boxKey: const Key('lp_approver_notes'), icon: Icons.check_circle_outline_rounded, title: 'Approver notes', body: notes, fg: AppColors.greenText, bg: AppColors.greenBg),
      if (p.status == LessonPlanStatus.submitted)
        const NoteBox(boxKey: Key('lp_under_review'), icon: Icons.hourglass_top_rounded, title: 'Awaiting approval', body: "It can't be edited while it is under review.", fg: AppColors.blue, bg: AppColors.pale),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoLine(icon: Icons.event_rounded, text: day == null ? 'No date' : fullDay(day)),
          if (p.durationMins != null) InfoLine(icon: Icons.schedule_rounded, text: '${p.durationMins} minutes'),
          if (method.isNotEmpty) InfoLine(icon: Icons.school_outlined, text: method),
          if (p.resources.isNotEmpty) InfoLine(icon: Icons.inventory_2_outlined, text: p.resources.join(', ')),
        ]),
      ),
      _section('Description', p.description),
      if (p.learningObjectives.isNotEmpty) ...[
        const SubHeading('Learning objectives'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < p.learningObjectives.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: CustomText(text: '${i + 1}. ${p.learningObjectives[i]}', fontSize: 12.5, height: 1.35)),
          ]),
        ),
      ],
      _section('Prior knowledge', p.priorKnowledge),
      _section('Activities', p.activities),
      _section('Assessment', p.assessment),
      _section('Homework', p.homework),
      const SizedBox(height: 14),
      if (p.canSubmit) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('lp_submit'),
            onPressed: busy ? null : () => _submit(context, p),
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 18),
            label: const CustomText(text: 'Submit for approval', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (p.canEdit)
        SizedBox(
          width: double.infinity,
          child: p.status == LessonPlanStatus.rejected
              ? ElevatedButton.icon(
                  key: const Key('lp_edit'),
                  onPressed: busy ? null : () => _edit(p),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const CustomText(text: 'Edit and resubmit', color: Colors.white, fontWeight: FontWeight.w700),
                )
              : OutlinedButton.icon(
                  key: const Key('lp_edit'),
                  onPressed: busy ? null : () => _edit(p),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const CustomText(text: 'Edit', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
                ),
        ),
      if (p.status == LessonPlanStatus.approved)
        const Padding(padding: EdgeInsets.only(top: 6), child: CustomText(text: "An approved plan can't be edited here. Ask your coordinator if it needs to change.", color: AppColors.muted, fontSize: 11)),
    ];
  }

  Future<void> _edit(LessonPlanRecord p) async {
    await Get.toNamed(Routes.lessonPlanNew, arguments: LessonPlanFormArgs(editing: p));
    controller.refreshFromList();
  }

  Future<void> _submit(BuildContext context, LessonPlanRecord p) async {
    final ok = await ConfirmDialog.show(
      title: 'Submit for approval?',
      message: '"${p.topic}" goes to your approver. You can\'t edit it while it is under review.',
      confirmLabel: 'Submit',
    );
    if (!ok) return;
    final r = await controller.submitForApproval();
    if (!context.mounted) return;
    switch (r) {
      case PlanSaved():
        ToastUtil.showToast('Submitted for approval');
      case PlanFailed(:final failure):
        _snack(context, failure.message);
      default:
        break;
    }
  }
}
