import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../../home/models/section_state.dart';
import '../controllers/homework_form_controller.dart';
import 'widgets/homework_widgets.dart';

/// New homework (`/homework/new`) or edit (`arguments: Assignment`): class and subject from MY assignments, due date, marks,
/// attachments with upload progress / retry, "Save draft" and "Assign to class".
class HomeworkNewScreen extends GetView<HomeworkFormController> {
  const HomeworkNewScreen({super.key});

  HomeworkFormController get c => controller;

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
          final leave = await ConfirmDialog.show(title: 'Discard this homework?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: Scaffold(
        appBar: AppBar(title: CustomText(text: c.isEditing ? 'Edit homework' : 'New homework', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        body: Obx(() {
          if (!c.isEditing && c.classes.isEmpty) {
            return const AppEmptyView(
              key: Key('hw_no_classes'),
              icon: Icons.school_outlined,
              title: "You aren't assigned to any class yet",
              subtitle: 'Homework is set for one of your classes. Ask your school admin to assign you to a class.',
            );
          }
          return Column(children: [
            Expanded(child: _form(context)),
            _BottomBar(onDraft: () => _submit(context, assign: false), onAssign: () => _submit(context, assign: true), controller: c),
          ]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final errors = c.errors;
    final failure = c.submitFailure.value;
    final notice = c.pickNotice.value;
    final due = c.dueDay.value;
    final selected = c.classIndex.value;
    final rosterState = c.roster.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('hw_submit_error'), message: failure.message),
        if (c.isEditing)
          AppCard(child: InfoLine(icon: Icons.groups_outlined, text: '${c.classLabel} · ${c.editing!.subject}'))
        else ...[
          FormLabel('Class *', error: errors['class']),
          ClassPicker(classes: c.classes, selected: selected, onSelect: c.selectClass),
          if (selected >= 0) Padding(padding: const EdgeInsets.only(top: 8), child: _RosterLine(state: rosterState, onRetry: c.retryRoster)),
          const SizedBox(height: 12),
          FormLabel('Subject *', error: errors['subject']),
          if (c.subjects.isEmpty)
            const CustomText(text: 'Choose a class first.', color: AppColors.muted, fontSize: 12)
          else
            ChoiceWrap(labels: c.subjects, selected: c.subject.value, onSelect: c.setSubject, keyPrefix: 'subject_'),
          const SizedBox(height: 14),
        ],
        const FormLabel('Type'),
        ChoiceWrap(
          labels: [for (final t in AssignmentType.values) t.label],
          selected: c.type.value.label,
          onSelect: (l) => c.setType(AssignmentType.values.firstWhere((t) => t.label == l)),
          keyPrefix: 'type_',
        ),
        const SizedBox(height: 14),
        LabeledField(label: 'Title', required: true, controller: c.titleC, fieldKey: const Key('hw_title_field'), hint: 'e.g. Exercise 5.3: factoring', error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'Description', controller: c.descriptionC, fieldKey: const Key('hw_desc_field'), maxLines: 3, hint: 'What should students do?'),
        LabeledField(label: 'Instructions', controller: c.instructionsC, fieldKey: const Key('hw_instr_field'), maxLines: 3, hint: 'Optional'),
        FormLabel('Due date *', error: errors['due']),
        InkWell(
          key: const Key('hw_due_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: due ?? today, firstDate: c.isEditing ? DateTime(today.year - 1) : today, lastDate: DateTime(today.year + 2, 12, 31));
            if (picked != null) c.setDueDay(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: errors['due'] == null ? AppColors.line : AppColors.redText)),
            child: Row(children: [
              const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryColor),
              const SizedBox(width: 10),
              CustomText(text: due == null ? 'Choose a date' : '${shortDay(due)} ${due.year}', color: due == null ? AppColors.faint : AppColors.black, fontWeight: FontWeight.w700, fontSize: 13),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LabeledField(
              label: 'Total marks',
              required: true,
              controller: c.totalC,
              fieldKey: const Key('hw_total_field'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              error: errors['total'],
              onChanged: (_) => c.errors.remove('total'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LabeledField(
              label: 'Passing marks',
              controller: c.passingC,
              fieldKey: const Key('hw_pass_field'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              error: errors['passing'],
              onChanged: (_) => c.errors.remove('passing'),
            ),
          ),
        ]),
        if (c.isEditing && !c.editing!.isDraft)
          const Padding(padding: EdgeInsets.only(bottom: 10), child: CustomText(text: "Total marks can't change once assigned: marks already given keep their maximum.", color: AppColors.muted, fontSize: 11)),
        FormLabel('Attachments', error: errors['attachments']),
        if (notice != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: CustomText(key: const Key('hw_pick_notice'), text: notice, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
        for (final a in c.attachments) _AttachmentRow(item: a, onRetry: () => c.retryUpload(a.id), onRemove: () => c.removeAttachment(a.id)),
        OutlinedButton.icon(
          key: const Key('hw_add_attachment'),
          onPressed: c.attachments.length >= HomeworkFormController.maxAttachments ? null : () => _chooseSource(context),
          icon: const Icon(Icons.attach_file_rounded, size: 18),
          label: const CustomText(text: 'Add attachment', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CustomText(text: 'PDF, JPG, PNG, WEBP, DOC or DOCX, up to 10 MB each (max 5).', color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _chooseSource(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('hw_pick_files'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Files'),
            onTap: () {
              Navigator.pop(ctx);
              c.pickDocuments();
            },
          ),
          ListTile(
            key: const Key('hw_pick_photos'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo library'),
            onTap: () {
              Navigator.pop(ctx);
              c.pickPhotos();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _submit(BuildContext context, {required bool assign}) async {
    if (assign) {
      final problems = c.validate();
      if (problems.isEmpty) {
        final ok = await ConfirmDialog.show(
          title: 'Assign to ${c.classLabel}?',
          message: 'The guardians of the students in this class will be notified now.',
          confirmLabel: 'Assign',
        );
        if (!ok) return;
      }
    }
    final r = await c.submit(assign: assign);
    if (!context.mounted) return;
    switch (r) {
      case FormSaved(:final assigned):
        ToastUtil.showToast(assigned ? 'Homework assigned' : (c.isEditing ? 'Changes saved' : 'Draft saved'));
        Get.back();
      case FormInvalid():
        _snack(context, r.errors.values.first);
      case FormFailed(:final failure):
        _snack(context, failure.message);
      case FormNoChanges():
        _snack(context, 'Nothing was changed.');
      case FormIgnored():
        break;
    }
  }
}

class _RosterLine extends StatelessWidget {
  final SectionState<ClassWire> state;
  final VoidCallback onRetry;
  const _RosterLine({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s.isLoading) return const CustomText(key: Key('hw_roster_loading'), text: 'Checking the class list...', color: AppColors.muted, fontSize: 11.5);
    final w = s.data;
    if (w == null) {
      return Row(children: [
        const Expanded(child: CustomText(key: Key('hw_roster_error'), text: "Couldn't load the class list. The class name from your profile will be used.", color: AppColors.amberText, fontSize: 11.5)),
        TextButton(onPressed: onRetry, child: const CustomText(text: 'Retry', color: AppColors.primaryColor, fontWeight: FontWeight.w800)),
      ]);
    }
    if (w.students == 0) {
      return const CustomText(key: Key('hw_roster_empty'), text: 'No active students found in this class.', color: AppColors.amberText, fontSize: 11.5);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CustomText(key: const Key('hw_roster_count'), text: '${w.students} ${w.students == 1 ? 'student' : 'students'} in this class', color: AppColors.muted, fontSize: 11.5),
      if (w.mismatched > 0)
        CustomText(
          key: const Key('hw_roster_mismatch'),
          text: '${w.mismatched} ${w.mismatched == 1 ? 'student is' : 'students are'} recorded under a different class spelling and may not receive this homework.',
          color: AppColors.amberText,
          fontSize: 11.5,
        ),
    ]);
  }
}

class _AttachmentRow extends StatelessWidget {
  final AttachmentItem item;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  const _AttachmentRow({required this.item, required this.onRetry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final st = item.status.value;
      final p = item.progress.value;
      final err = item.error.value;
      return Container(
        key: ValueKey('att_${item.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: st == UploadStatus.failed ? AppColors.redText : AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(st == UploadStatus.done ? Icons.check_circle_rounded : (st == UploadStatus.failed ? Icons.error_rounded : Icons.cloud_upload_outlined),
                size: 18, color: st == UploadStatus.done ? AppColors.greenText : (st == UploadStatus.failed ? AppColors.redText : AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CustomText(text: item.name, fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.size > 0) CustomText(text: sizeText(item.size), color: AppColors.muted, fontSize: 10.5),
              ]),
            ),
            if (st == UploadStatus.failed) TextButton(key: ValueKey('retry_${item.id}'), onPressed: onRetry, child: const CustomText(text: 'Retry', color: AppColors.primaryColor, fontWeight: FontWeight.w800)),
            IconButton(key: ValueKey('remove_${item.id}'), onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted)),
          ]),
          if (st == UploadStatus.uploading)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(key: ValueKey('progress_${item.id}'), value: p > 0 ? p : null, minHeight: 5, color: AppColors.primaryColor, backgroundColor: AppColors.pale))),
                const SizedBox(width: 8),
                CustomText(text: p >= 1 ? 'Finishing...' : '${(p * 100).round()}%', color: AppColors.muted, fontSize: 10.5),
              ]),
            ),
          if (st == UploadStatus.failed && err != null) Padding(padding: const EdgeInsets.only(right: 8, bottom: 4), child: CustomText(key: ValueKey('att_err_${item.id}'), text: err, color: AppColors.redText, fontSize: 11)),
        ]),
      );
    });
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onDraft;
  final VoidCallback onAssign;
  final HomeworkFormController controller;
  const _BottomBar({required this.onDraft, required this.onAssign, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller;
      final saving = c.saving.value;
      final uploading = c.hasUploading;
      final busy = saving || uploading;
      final editingAssigned = c.isEditing && !c.editing!.isDraft;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(children: [
            if (!editingAssigned)
              Expanded(
                child: OutlinedButton(
                  key: const Key('hw_save_draft'),
                  onPressed: busy ? null : onDraft,
                  child: CustomText(text: c.isEditing ? 'Save draft' : 'Save as draft', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
                ),
              ),
            if (!editingAssigned) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                key: const Key('hw_submit'),
                onPressed: busy ? null : (editingAssigned ? onDraft : onAssign),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : CustomText(text: uploading ? 'Uploading...' : (editingAssigned ? 'Save changes' : 'Assign to class'), color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
