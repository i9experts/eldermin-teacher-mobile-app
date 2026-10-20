import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../common/action_failure.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../../home/models/section_state.dart';
import '../controllers/homework_form_controller.dart';
import 'widgets/homework_widgets.dart';
import '../../../../core/design/design.dart';

/// New homework (`/homework/new`) or edit (`arguments: Assignment`): class and subject from MY assignments, due date, marks,
/// attachments with upload progress / retry, "Save draft" and "Assign to class".
class HomeworkNewScreen extends GetView<HomeworkFormController> {
  const HomeworkNewScreen({super.key});

  HomeworkFormController get c => controller;

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
          final leave = await ConfirmDialog.show(title: 'Discard this homework?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: c.isEditing ? 'Edit homework' : 'New homework'),
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
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('hw_submit_error'), message: failure.message),
        if (c.isEditing)
          AppCard(child: InfoLine(icon: Icons.groups_outlined, text: '${c.classLabel} · ${c.editing!.subject}'))
        else ...[
          FormLabel('Class *', error: errors['class']),
          ClassPicker(classes: c.classes, selected: selected, onSelect: c.selectClass),
          if (selected >= 0) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: _RosterLine(state: rosterState, onRetry: c.retryRoster)),
          const SizedBox(height: EmSpacing.row),
          FormLabel('Subject *', error: errors['subject']),
          if (c.subjects.isEmpty)
            Text('Choose a class first.', style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))
          else
            ChoiceWrap(labels: c.subjects, selected: c.subject.value, onSelect: c.setSubject, keyPrefix: 'subject_'),
          const SizedBox(height: EmSpacing.block),
        ],
        const FormLabel('Type'),
        ChoiceWrap(
          labels: [for (final t in AssignmentType.values) t.label],
          selected: c.type.value.label,
          onSelect: (l) => c.setType(AssignmentType.values.firstWhere((t) => t.label == l)),
          keyPrefix: 'type_',
        ),
        const SizedBox(height: EmSpacing.block),
        LabeledField(label: 'Title', required: true, controller: c.titleC, fieldKey: const Key('hw_title_field'), hint: 'e.g. Exercise 5.3: factoring', error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'Description', controller: c.descriptionC, fieldKey: const Key('hw_desc_field'), maxLines: 3, hint: 'What should students do?'),
        LabeledField(label: 'Instructions', controller: c.instructionsC, fieldKey: const Key('hw_instr_field'), maxLines: 3, hint: 'Optional'),
        FormLabel('Due date *', error: errors['due']),
        InkWell(
          key: const Key('hw_due_picker'),
          borderRadius: EmRadius.mdAll,
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: due ?? today, firstDate: c.isEditing ? DateTime(today.year - 1) : today, lastDate: DateTime(today.year + 2, 12, 31));
            if (picked != null) c.setDueDay(picked);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
            child: DecoratedBox(
              decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: errors['due'] == null ? EmColors.border : EmColors.error)),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s16, vertical: EmSpacing.s12),
                child: Row(children: [
                  const ExcludeSemantics(child: Icon(Icons.event_rounded, size: 20, color: EmColors.primary)),
                  const SizedBox(width: EmSpacing.s12),
                  Expanded(child: Text(due == null ? 'Choose a date' : '${shortDay(due)} ${due.year}', style: EmType.body.copyWith(color: due == null ? EmColors.textTertiary : EmColors.ink))),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: EmSpacing.block),
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
          const SizedBox(width: EmSpacing.row),
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
          Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s12), child: Text("Total marks can't change once assigned: marks already given keep their maximum.", style: EmType.caption.copyWith(color: EmColors.textSecondary))),
        FormLabel('Attachments', error: errors['attachments']),
        if (notice != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text(notice, key: const Key('hw_pick_notice'), style: EmType.caption.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
        for (final a in c.attachments) _AttachmentRow(item: a, onRetry: () => c.retryUpload(a.id), onRemove: () => c.removeAttachment(a.id)),
        EmSecondaryButton(
          key: const Key('hw_add_attachment'),
          expand: true,
          icon: Icons.attach_file_rounded,
          label: 'Add attachment',
          onPressed: c.attachments.length >= HomeworkFormController.maxAttachments ? null : () => _chooseSource(context),
        ),
        Padding(
          padding: const EdgeInsets.only(top: EmSpacing.s8),
          child: Text('PDF, JPG, PNG, WEBP, DOC or DOCX, up to 10 MB each (max 5).', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ),
      ],
    );
  }

  Future<void> _chooseSource(BuildContext context) async {
    await EmBottomSheet.showPanel<void>(
      context,
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
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    final warn = EmType.caption.copyWith(color: EmColors.onWarningContainer);
    if (s.isLoading) return Text('Checking the class list...', key: const Key('hw_roster_loading'), style: quiet);
    final w = s.data;
    if (w == null) {
      return Row(children: [
        Expanded(child: Text("Couldn't load the class list. The class name from your profile will be used.", key: const Key('hw_roster_error'), style: warn)),
        TextButton(onPressed: onRetry, child: Text('Retry', style: EmType.label.copyWith(color: EmColors.primary))),
      ]);
    }
    if (w.students == 0) return Text('No active students found in this class.', key: const Key('hw_roster_empty'), style: warn);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${w.students} ${w.students == 1 ? 'student' : 'students'} in this class', key: const Key('hw_roster_count'), style: quiet),
      if (w.mismatched > 0)
        Text(
          '${w.mismatched} ${w.mismatched == 1 ? 'student is' : 'students are'} recorded under a different class spelling and may not receive this homework.',
          key: const Key('hw_roster_mismatch'),
          style: warn,
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
      final unavailable = item.unavailable.value;
      final failed = st == UploadStatus.failed;
      final errStyle = EmType.caption.copyWith(color: EmColors.onErrorContainer);
      return Padding(
        key: ValueKey('att_${item.id}'),
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: EmCard(
          color: failed ? EmColors.errorContainer : EmColors.surface,
          padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s12, EmSpacing.s8, EmSpacing.s4, EmSpacing.s8),
          radius: EmRadius.md,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ExcludeSemantics(
                child: Icon(
                  st == UploadStatus.done ? Icons.check_circle_rounded : (failed ? Icons.error_rounded : Icons.cloud_upload_outlined),
                  size: 20,
                  color: st == UploadStatus.done ? EmColors.onSuccessContainer : (failed ? EmColors.onErrorContainer : EmColors.textSecondary),
                ),
              ),
              const SizedBox(width: EmSpacing.s8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                  if (item.size > 0) Text(sizeText(item.size), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                ]),
              ),
              if (failed && !unavailable) TextButton(key: ValueKey('retry_${item.id}'), onPressed: onRetry, child: Text('Retry', style: EmType.label.copyWith(color: EmColors.primary))),
              IconButton(key: ValueKey('remove_${item.id}'), tooltip: 'Remove', onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 20, color: EmColors.textSecondary)),
            ]),
            if (st == UploadStatus.uploading)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8, bottom: EmSpacing.s4),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: EmRadius.pillAll,
                      child: LinearProgressIndicator(key: ValueKey('progress_${item.id}'), value: p > 0 ? p : null, minHeight: EmSpacing.s8, color: EmColors.primary, backgroundColor: EmColors.primaryLight),
                    ),
                  ),
                  const SizedBox(width: EmSpacing.s8),
                  Text(p >= 1 ? 'Finishing...' : '${(p * 100).round()}%', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                ]),
              ),
            if (failed && unavailable)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8, bottom: EmSpacing.s4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ActionFailure.uploadUnavailableTitle, key: ValueKey('att_unavailable_title_${item.id}'), style: errStyle.copyWith(fontWeight: FontWeight.w600)),
                  if (err != null) Text(err, key: ValueKey('att_err_${item.id}'), style: errStyle),
                  TextButton(key: ValueKey('continue_without_${item.id}'), onPressed: onRemove, child: Text('Continue without attachment', style: EmType.label.copyWith(color: EmColors.primary))),
                ]),
              )
            else if (failed && err != null)
              Padding(padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8, bottom: EmSpacing.s4), child: Text(err, key: ValueKey('att_err_${item.id}'), style: errStyle)),
          ]),
        ),
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
      return DecoratedBox(
        decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s12),
            child: Row(children: [
              if (!editingAssigned) ...[
                Expanded(child: EmSecondaryButton(key: const Key('hw_save_draft'), expand: true, label: c.isEditing ? 'Save draft' : 'Save as draft', onPressed: busy ? null : onDraft)),
                const SizedBox(width: EmSpacing.s12),
              ],
              Expanded(
                child: EmPrimaryButton(
                  key: const Key('hw_submit'),
                  loading: saving,
                  label: uploading ? 'Uploading...' : (editingAssigned ? 'Save changes' : 'Assign to class'),
                  onPressed: busy ? null : (editingAssigned ? onDraft : onAssign),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
