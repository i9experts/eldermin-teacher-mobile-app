import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show InfoLine;
import '../controllers/lesson_plan_detail_controller.dart';
import '../controllers/lesson_plan_form_controller.dart';
import 'widgets/lesson_plan_widgets.dart';
import '../../../../core/design/design.dart';
import '../../../common/write_access.dart';

/// One plan (`/lesson-plans/:id`): all fields, status, the rejection reason (ONLY when rejected) or approver notes (ONLY when approved),
/// and the actions the status allows: submit, edit, edit and resubmit. Approving / rejecting is a coordinator action and is not offered.
class LessonPlanDetailScreen extends GetView<LessonPlanDetailController> {
  const LessonPlanDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Lesson plan'),
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
    ..showSnackBar(SnackBar(content: Text(m)));

  Widget _section(String title, String text, {Key? k}) => text.trim().isEmpty
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionRow(title: title), AppCard(child: Text(text, key: k, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5)))]);

  List<Widget> _content(BuildContext context, LessonPlanRecord p, bool busy, String? failure) {
    final day = p.planDay;
    final reason = p.rejectionReason;
    final notes = p.approverNotes;
    final method = kLessonMethodologies[p.teachingMethodology] ?? p.teachingMethodology;
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(p.topic.isEmpty ? '(No topic)' : p.topic, key: const Key('lp_topic'), style: EmType.title.copyWith(color: EmColors.ink))),
        const SizedBox(width: EmSpacing.s8),
        PlanStatusTag(p.status),
      ]),
      const SizedBox(height: EmSpacing.s4),
      Text([p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
      const SizedBox(height: EmSpacing.block),
      if (failure != null) NoteBox(boxKey: const Key('lp_action_error'), icon: Icons.error_outline_rounded, title: failure, tone: EmTone.error),
      // Shown ONLY for a rejected plan: the server keeps an old reason on a resubmitted one (raw $set, teaching.service.ts:191-207).
      if (p.status == LessonPlanStatus.rejected)
        NoteBox(
          boxKey: const Key('lp_rejection'),
          icon: Icons.cancel_outlined,
          title: 'Rejected by your approver',
          body: reason == null || reason.isEmpty ? 'No reason was given.' : reason,
          tone: EmTone.error,
        ),
      if (p.status == LessonPlanStatus.approved && notes != null && notes.isNotEmpty)
        NoteBox(boxKey: const Key('lp_approver_notes'), icon: Icons.check_circle_outline_rounded, title: 'Approver notes', body: notes, tone: EmTone.success),
      if (p.status == LessonPlanStatus.submitted)
        const NoteBox(boxKey: Key('lp_under_review'), icon: Icons.hourglass_top_rounded, title: 'Awaiting approval', body: "It can't be edited while it is under review.", tone: EmTone.info),
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
        const SectionRow(title: 'Learning objectives'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < p.learningObjectives.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text('${i + 1}. ${p.learningObjectives[i]}', style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.4))),
          ]),
        ),
      ],
      _section('Prior knowledge', p.priorKnowledge),
      _section('Activities', p.activities),
      _section('Assessment', p.assessment),
      _section('Homework', p.homework),
      const SizedBox(height: EmSpacing.block),
      if (p.canSubmit && canWriteLessonPlans) ...[
        EmPrimaryButton(key: const Key('lp_submit'), icon: Icons.send_rounded, loading: busy, label: 'Submit for approval', onPressed: busy ? null : () => _submit(context, p)),
        const SizedBox(height: EmSpacing.s8),
      ],
      if (p.canEdit && canWriteLessonPlans)
        p.status == LessonPlanStatus.rejected
            ? EmPrimaryButton(key: const Key('lp_edit'), icon: Icons.edit_outlined, label: 'Edit and resubmit', onPressed: busy ? null : () => _edit(p))
            : EmSecondaryButton(key: const Key('lp_edit'), expand: true, icon: Icons.edit_outlined, label: 'Edit', onPressed: busy ? null : () => _edit(p)),
      if (p.status == LessonPlanStatus.approved)
        Padding(
          padding: const EdgeInsets.only(top: EmSpacing.s8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ExcludeSemantics(child: Icon(Icons.lock_outline_rounded, size: 16, color: EmColors.textSecondary)),
            const SizedBox(width: EmSpacing.s4),
            Expanded(child: Text("An approved plan can't be edited here. Ask your coordinator if it needs to change.", style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          ]),
        ),
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
