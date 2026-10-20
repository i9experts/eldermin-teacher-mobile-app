import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ChoiceWrap, FormLabel, InfoLine, LabeledField;
import '../../students/views/widgets/student_widgets.dart' show ClassPicker;
import '../controllers/lesson_plan_form_controller.dart';
import 'widgets/lesson_plan_widgets.dart';
import '../../../../core/design/design.dart';

/// New lesson plan (`/lesson-plans/new`), edit (`arguments: LessonPlanFormArgs(editing)`), or review of a parsed draft
/// (`arguments: LessonPlanFormArgs(draft)`). Class and subject come from MY assignments. "Save as draft" or "Submit for approval".
class LessonPlanNewScreen extends GetView<LessonPlanFormController> {
  const LessonPlanNewScreen({super.key});

  LessonPlanFormController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), margin: EmSpacing.snackAboveBar));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this lesson plan?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(
          title: c.isEditing ? (c.editing!.status == LessonPlanStatus.rejected ? 'Edit and resubmit' : 'Edit lesson plan') : 'New lesson plan',
        ),
        body: Obx(() {
          if (!c.isEditing && c.classes.isEmpty) {
            return const AppEmptyView(
              key: Key('lp_no_classes'),
              icon: Icons.school_outlined,
              title: "You aren't assigned to any class yet",
              subtitle: 'A lesson plan is written for one of your classes. Ask your school admin to assign you to a class.',
            );
          }
          return Column(children: [Expanded(child: _form(context)), _BottomBar(controller: c, onDraft: () => _submit(context, forApproval: false), onSubmit: () => _submit(context, forApproval: true))]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final errors = c.errors;
    final failure = c.submitFailure.value;
    final selected = c.classIndex.value;
    final day = c.planDay.value;
    final method = c.methodology.value;
    final picked = c.resources.toSet();
    final objectives = c.objectives.toList();
    final from = c.prefilledFrom.value;
    final warnings = c.prefillWarnings.toList();
    final hint = c.prefillHint.value;
    final rej = c.editing?.status == LessonPlanStatus.rejected ? c.editing!.rejectionReason : null;
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) NoteBox(boxKey: const Key('lp_submit_error'), icon: Icons.error_outline_rounded, title: failure.message, tone: EmTone.error),
        if (c.editing?.status == LessonPlanStatus.rejected)
          NoteBox(
            boxKey: const Key('lp_edit_rejection'),
            icon: Icons.cancel_outlined,
            title: 'Rejected by your approver',
            body: rej == null || rej.isEmpty ? 'No reason was given.' : rej,
            tone: EmTone.error,
          ),
        if (from != null)
          NoteBox(
            boxKey: const Key('lp_prefill_banner'),
            icon: Icons.auto_awesome_outlined,
            title: 'Prefilled from $from',
            body: 'This is an AI-assisted draft. Check every field before you save or submit. Nothing has been saved yet.',
            tone: EmTone.info,
          ),
        if (warnings.isNotEmpty)
          NoteBox(boxKey: const Key('lp_prefill_warnings'), icon: Icons.warning_amber_rounded, title: 'Notes from the reader', body: warnings.map((w) => '• $w').join('\n'), tone: EmTone.warning),
        if (hint != null) EmInfoBanner(key: const Key('lp_prefill_hint'), tone: EmTone.warning, text: hint),
        if (c.isEditing)
          AppCard(child: InfoLine(icon: Icons.groups_outlined, text: '${c.classLabel} · ${c.subjectLabel}'))
        else ...[
          FormLabel('Class *', error: errors['class']),
          ClassPicker(classes: c.classes, selected: selected, onSelect: c.selectClass),
          const SizedBox(height: EmSpacing.row),
          FormLabel('Subject *', error: errors['subject']),
          if (c.subjects.isEmpty)
            Text('Choose a class first.', style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))
          else
            ChoiceWrap(labels: c.subjects, selected: c.subject.value, onSelect: c.setSubject, keyPrefix: 'subject_'),
          const SizedBox(height: EmSpacing.block),
        ],
        LabeledField(label: 'Topic', required: true, controller: c.topicC, fieldKey: const Key('lp_topic_field'), hint: 'e.g. Adding fractions', error: errors['topic'], onChanged: (_) => c.errors.remove('topic')),
        FormLabel('Lesson date *', error: errors['date']),
        KeyedSubtree(
          key: const Key('lp_date_picker'),
          child: EmSelectField(
            icon: Icons.event_rounded,
            trailingIcon: null,
            title: day == null ? null : '${shortDay(day)} ${day.year}',
            placeholder: 'Choose a date',
            hasError: errors['date'] != null,
            onTap: () async {
              final today = c.today;
              final picked = await showAppDatePicker(context, initialDate: day ?? today, firstDate: DateTime(today.year - 1, today.month, today.day), lastDate: DateTime(today.year + 1, 12, 31));
              if (picked != null) c.setPlanDay(picked);
            },
          ),
        ),
        const SizedBox(height: EmSpacing.block),
        LabeledField(label: 'Duration (minutes)', controller: c.durationC, fieldKey: const Key('lp_duration_field'), keyboardType: TextInputType.number, hint: '40', error: errors['duration'], onChanged: (_) => c.errors.remove('duration')),
        LabeledField(label: 'Description', controller: c.descriptionC, fieldKey: const Key('lp_desc_field'), maxLines: 3, hint: 'A short summary of the lesson'),
        const FormLabel('Learning objectives'),
        for (var i = 0; i < objectives.length; i++)
          Padding(
            key: ValueKey('lp_obj_row_${objectives[i].id}'),
            padding: const EdgeInsets.only(bottom: EmSpacing.s8),
            child: Row(children: [
              Text('${i + 1}.', style: EmType.label.copyWith(color: EmColors.textSecondary)),
              const SizedBox(width: EmSpacing.s8),
              Expanded(
                child: TextField(
                  key: ValueKey('lp_obj_${objectives[i].id}'),
                  controller: objectives[i].controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: EmType.body.copyWith(color: EmColors.ink),
                  decoration: const InputDecoration(isDense: true, hintText: 'Students will be able to...'),
                ),
              ),
              IconButton(key: ValueKey('lp_obj_remove_${objectives[i].id}'), tooltip: 'Remove objective', onPressed: () => c.removeObjective(objectives[i].id), icon: const Icon(Icons.close_rounded, size: 20, color: EmColors.textSecondary)),
            ]),
          ),
        Align(alignment: AlignmentDirectional.centerStart, child: EmTextAction(key: const Key('lp_add_objective'), onPressed: c.addObjective, icon: Icons.add_rounded, label: 'Add objective')),
        const SizedBox(height: EmSpacing.s4),
        const FormLabel('Teaching method'),
        Wrap(spacing: EmSpacing.s8, children: [
          for (final e in kLessonMethodologies.entries) EmChip(key: Key('method_${e.key}'), label: e.value, selected: method == e.key, onTap: () => c.setMethodology(e.key)),
        ]),
        const SizedBox(height: EmSpacing.block),
        const FormLabel('Resources'),
        Wrap(spacing: EmSpacing.s8, children: [
          for (final r in kLessonResources) EmChip(key: Key('res_$r'), label: r, selected: picked.contains(r), icon: picked.contains(r) ? Icons.check_rounded : null, onTap: () => c.toggleResource(r)),
        ]),
        const SizedBox(height: EmSpacing.row),
        LabeledField(label: 'Other resources', controller: c.otherResourceC, fieldKey: const Key('lp_other_res_field'), hint: 'Separate with ;  e.g. paper strips; scissors'),
        LabeledField(label: 'Prior knowledge', controller: c.priorC, fieldKey: const Key('lp_prior_field'), maxLines: 2),
        LabeledField(label: 'Activities', controller: c.activitiesC, fieldKey: const Key('lp_activities_field'), maxLines: 3, hint: 'What will students do?'),
        LabeledField(label: 'Assessment', controller: c.assessmentC, fieldKey: const Key('lp_assessment_field'), maxLines: 2, hint: 'How will you check understanding?'),
        LabeledField(label: 'Homework', controller: c.homeworkC, fieldKey: const Key('lp_homework_field'), maxLines: 2),
      ],
    );
  }

  Future<void> _submit(BuildContext context, {required bool forApproval}) async {
    if (forApproval) {
      final problems = c.validate();
      if (problems.isEmpty) {
        final ok = await ConfirmDialog.show(
          title: 'Submit for approval?',
          message: 'Your approver will review "${c.topicC.text.trim()}". You can\'t edit it while it is under review.',
          confirmLabel: 'Submit',
        );
        if (!ok) return;
      }
    }
    final r = await c.submit(forApproval: forApproval);
    if (!context.mounted) return;
    switch (r) {
      case PlanSaved(:final submitted):
        ToastUtil.showToast(submitted ? 'Submitted for approval' : (c.isEditing ? 'Changes saved' : 'Draft saved'));
        Get.back();
      case PlanInvalid():
        _snack(context, r.errors.values.first);
      case PlanFailed(:final failure):
        _snack(context, failure.message);
      case PlanNoChanges():
        _snack(context, 'Nothing was changed.');
      case PlanIgnored():
        break;
    }
  }
}

class _BottomBar extends StatelessWidget {
  final LessonPlanFormController controller;
  final VoidCallback onDraft;
  final VoidCallback onSubmit;
  const _BottomBar({required this.controller, required this.onDraft, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller;
      final saving = c.saving.value;
      final rejected = c.editing?.status == LessonPlanStatus.rejected;
      return DecoratedBox(
        decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s12),
            child: Row(children: [
              Expanded(child: EmSecondaryButton(key: const Key('lp_save_draft'), expand: true, label: c.isEditing ? 'Save changes' : 'Save as draft', onPressed: saving ? null : onDraft)),
              const SizedBox(width: EmSpacing.s12),
              Expanded(child: EmPrimaryButton(key: const Key('lp_submit_approval'), loading: saving, label: rejected ? 'Save and resubmit' : 'Submit for approval', onPressed: saving ? null : onSubmit)),
            ]),
          ),
        ),
      );
    });
  }
}
