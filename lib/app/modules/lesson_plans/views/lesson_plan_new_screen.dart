import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ChoiceWrap, FormLabel, InfoLine, LabeledField;
import '../../students/views/widgets/student_widgets.dart' show ClassPicker;
import '../controllers/lesson_plan_form_controller.dart';
import 'widgets/lesson_plan_widgets.dart';

/// New lesson plan (`/lesson-plans/new`), edit (`arguments: LessonPlanFormArgs(editing)`), or review of a parsed draft
/// (`arguments: LessonPlanFormArgs(draft)`). Class and subject come from MY assignments. "Save as draft" or "Submit for approval".
class LessonPlanNewScreen extends GetView<LessonPlanFormController> {
  const LessonPlanNewScreen({super.key});

  LessonPlanFormController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 100)));

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
      child: Scaffold(
        appBar: AppBar(
          title: CustomText(
            text: c.isEditing ? (c.editing!.status == LessonPlanStatus.rejected ? 'Edit and resubmit' : 'Edit lesson plan') : 'New lesson plan',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (failure != null) NoteBox(boxKey: const Key('lp_submit_error'), icon: Icons.error_outline_rounded, title: failure.message, fg: AppColors.redText, bg: AppColors.redBg),
        if (c.editing?.status == LessonPlanStatus.rejected)
          NoteBox(
            boxKey: const Key('lp_edit_rejection'),
            icon: Icons.cancel_outlined,
            title: 'Rejected by your approver',
            body: rej == null || rej.isEmpty ? 'No reason was given.' : rej,
            fg: AppColors.redText,
            bg: AppColors.redBg,
          ),
        if (from != null)
          NoteBox(
            boxKey: const Key('lp_prefill_banner'),
            icon: Icons.auto_awesome_outlined,
            title: 'Prefilled from $from',
            body: 'This is an AI-assisted draft. Check every field before you save or submit. Nothing has been saved yet.',
            fg: AppColors.blue,
            bg: AppColors.pale,
          ),
        if (warnings.isNotEmpty)
          NoteBox(boxKey: const Key('lp_prefill_warnings'), icon: Icons.warning_amber_rounded, title: 'Notes from the reader', body: warnings.map((w) => '• $w').join('\n'), fg: AppColors.amberText, bg: AppColors.amberBg),
        if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: CustomText(key: const Key('lp_prefill_hint'), text: hint, color: AppColors.amberText, fontSize: 12, fontWeight: FontWeight.w700)),
        if (c.isEditing)
          AppCard(child: InfoLine(icon: Icons.groups_outlined, text: '${c.classLabel} · ${c.subjectLabel}'))
        else ...[
          FormLabel('Class *', error: errors['class']),
          ClassPicker(classes: c.classes, selected: selected, onSelect: c.selectClass),
          const SizedBox(height: 12),
          FormLabel('Subject *', error: errors['subject']),
          if (c.subjects.isEmpty)
            const CustomText(text: 'Choose a class first.', color: AppColors.muted, fontSize: 12)
          else
            ChoiceWrap(labels: c.subjects, selected: c.subject.value, onSelect: c.setSubject, keyPrefix: 'subject_'),
          const SizedBox(height: 14),
        ],
        LabeledField(label: 'Topic', required: true, controller: c.topicC, fieldKey: const Key('lp_topic_field'), hint: 'e.g. Adding fractions', error: errors['topic'], onChanged: (_) => c.errors.remove('topic')),
        FormLabel('Lesson date *', error: errors['date']),
        InkWell(
          key: const Key('lp_date_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: day ?? today, firstDate: DateTime(today.year - 1, today.month, today.day), lastDate: DateTime(today.year + 1, 12, 31));
            if (picked != null) c.setPlanDay(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: errors['date'] == null ? AppColors.line : AppColors.redText)),
            child: Row(children: [
              const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryColor),
              const SizedBox(width: 10),
              CustomText(text: day == null ? 'Choose a date' : '${shortDay(day)} ${day.year}', color: day == null ? AppColors.faint : AppColors.black, fontWeight: FontWeight.w700, fontSize: 13),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(label: 'Duration (minutes)', controller: c.durationC, fieldKey: const Key('lp_duration_field'), keyboardType: TextInputType.number, hint: '40', error: errors['duration'], onChanged: (_) => c.errors.remove('duration')),
        LabeledField(label: 'Description', controller: c.descriptionC, fieldKey: const Key('lp_desc_field'), maxLines: 3, hint: 'A short summary of the lesson'),
        const FormLabel('Learning objectives'),
        for (var i = 0; i < objectives.length; i++)
          Padding(
            key: ValueKey('lp_obj_row_${objectives[i].id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CustomText(text: '${i + 1}.', color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: ValueKey('lp_obj_${objectives[i].id}'),
                  controller: objectives[i].controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Students will be able to...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              IconButton(key: ValueKey('lp_obj_remove_${objectives[i].id}'), onPressed: () => c.removeObjective(objectives[i].id), icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted)),
            ]),
          ),
        TextButton.icon(
          key: const Key('lp_add_objective'),
          onPressed: c.addObjective,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const CustomText(text: 'Add objective', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const FormLabel('Teaching method'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kLessonMethodologies.entries)
            _Chip(key: Key('method_${e.key}'), label: e.value, on: method == e.key, onTap: () => c.setMethodology(e.key)),
        ]),
        const SizedBox(height: 14),
        const FormLabel('Resources'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in kLessonResources) _Chip(key: Key('res_$r'), label: r, on: picked.contains(r), onTap: () => c.toggleResource(r), check: true),
        ]),
        const SizedBox(height: 10),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool check;
  const _Chip({super.key, required this.label, required this.on, required this.onTap, this.check = false});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: on ? AppColors.primaryColor : Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: on ? AppColors.primaryColor : AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (check && on) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check_rounded, size: 14, color: Colors.white)),
            CustomText(text: label, color: on ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
          ]),
        ),
      );
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
      final e = c.editing;
      final rejected = e?.status == LessonPlanStatus.rejected;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('lp_save_draft'),
                onPressed: saving ? null : onDraft,
                child: CustomText(text: c.isEditing ? 'Save changes' : 'Save as draft', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                key: const Key('lp_submit_approval'),
                onPressed: saving ? null : onSubmit,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : CustomText(text: rejected ? 'Save and resubmit' : 'Submit for approval', color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
