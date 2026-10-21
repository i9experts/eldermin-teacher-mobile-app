import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../common/action_failure.dart';
import '../../../routes/app_routes.dart';
import '../../behaviour/views/widgets/behaviour_widgets.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../home/models/section_state.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/new_thread_controller.dart';
import '../../../../core/design/design.dart';

/// Start a conversation (`/messages/new`): student -> guardian -> subject + first message.
class MessageNewScreen extends GetView<NewThreadController> {
  const MessageNewScreen({super.key});

  NewThreadController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this message?', message: 'What you wrote will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'New message'),
        body: Obx(() {
          if (c.classes.isEmpty) {
            return const AppEmptyView(key: Key('new_no_classes'), icon: Icons.school_outlined, title: "You aren't assigned to any class yet", subtitle: 'You can message the guardians of students in your classes.');
          }
          return Column(children: [Expanded(child: _form(context)), _bottom(context)]);
        }),
      ),
    );
  }

  String _failureText(ActionFailure f) => f.kind == ActionFailureKind.forbidden && f.serverMessage.isNotEmpty ? f.serverMessage : f.message;

  Widget _form(BuildContext context) {
    final errors = c.errors;
    final failure = c.failure.value;
    final student = c.student.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('new_submit_error'), message: _failureText(failure)),
        FormLabel('Student *', error: errors['student']),
        InkWell(
          key: const Key('new_student_picker'),
          borderRadius: EmRadius.mdAll,
          onTap: () => _pickStudent(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
            padding: const EdgeInsets.all(EmSpacing.s12),
            decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: errors['student'] == null ? EmColors.border : EmColors.error)),
            child: Row(children: [
              if (student != null) ...[StudentAvatar(student: student, size: 34), const SizedBox(width: EmSpacing.s12)] else const Padding(padding: EdgeInsetsDirectional.only(end: EmSpacing.s12), child: Icon(Icons.person_search_rounded, color: EmColors.primary)),
              Expanded(
                child: student == null
                    ? Text('Choose a student from your classes', style: EmType.label.copyWith(color: EmColors.textSecondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(student.fullName, key: const Key('new_selected_student'), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.primary)),
                        Text(student.classLabel, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                      ]),
              ),
              const Icon(Icons.expand_more_rounded, color: EmColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: EmSpacing.block),
        if (student != null) ...[
          FormLabel('Guardian *', error: errors['guardian']),
          _guardians(),
          const SizedBox(height: EmSpacing.s8),
          const ParentVisibleNote(text: 'You message guardians inside the app. Their phone number and email are not shown to you.'),
          const SizedBox(height: EmSpacing.block),
        ],
        LabeledField(label: 'Subject', required: true, controller: c.subjectC, fieldKey: const Key('new_subject'), maxLength: NewThreadRequest.subjectMax, hint: 'e.g. Homework this week', error: errors['subject'], onChanged: (_) => c.errors.remove('subject')),
        LabeledField(label: 'Message', required: true, controller: c.messageC, fieldKey: const Key('new_message'), maxLines: 5, maxLength: NewThreadRequest.messageMax, hint: 'Write your message', error: errors['message'], onChanged: (_) => c.errors.remove('message')),
      ],
    );
  }

  Widget _guardians() {
    final st = c.guardians.value;
    switch (st.status) {
      case SectionStatus.loading:
        return AppShimmer(key: const Key('new_guardians_loading'), child: const ShimmerListRowSkeleton());
      case SectionStatus.forbidden:
        return ErrorBanner(bannerKey: const Key('new_guardians_denied'), message: c.guardiansDenied.value ?? "You can't message this student's guardians.");
      case SectionStatus.unavailable:
        return const ErrorBanner(bannerKey: Key('new_guardians_unavailable'), message: 'Not available on this server yet.');
      case SectionStatus.error:
        return ErrorBanner(bannerKey: const Key('new_guardians_error'), message: st.message ?? 'Something went wrong', onRetry: c.loadGuardians);
      case SectionStatus.empty:
        return AppCard(key: const Key('new_guardians_empty'), child: Text('No guardian account is registered for this student, so there is nobody to message in the app.', style: EmType.caption.copyWith(color: EmColors.textSecondary)));
      case SectionStatus.data:
        final sel = c.guardian.value;
        return Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final g in st.data!)
            EmChip(
              key: Key('guardian_${g.userId}'),
              label: g.display,
              icon: sel?.userId == g.userId ? Icons.check_rounded : null,
              selected: sel?.userId == g.userId,
              onTap: () => c.selectGuardian(g),
            ),
        ]);
    }
  }

  Widget _bottom(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
        decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
        child: Obx(() => EmPrimaryButton(
              key: const Key('new_submit'),
              label: 'Send message',
              loading: c.saving.value,
              onPressed: c.saving.value ? null : () => _submit(context),
            )),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case StartCreated(:final thread):
        Get.offNamed(Routes.messageThreadOf(thread.id));
      case StartInvalid():
        _snack(context, r.errors.values.first);
      case StartFailed(:final failure):
        _snack(context, _failureText(failure));
      case StartIgnored():
        break;
    }
  }

  Future<void> _pickStudent(BuildContext context) async {
    c.picker.load();
    await EmBottomSheet.showPanel<void>(context, heightFactor: 0.85, builder: (_) => _PickerSheet(controller: c));
  }
}

class _PickerSheet extends StatelessWidget {
  final NewThreadController controller;
  const _PickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = controller.picker;
    return Padding(
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose a student', style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s12),
        Obx(() {
          final cs = p.classes;
          final sel = p.selectedClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s12), child: ClassPicker(classes: cs, selected: sel, onSelect: p.selectClass)) : const SizedBox.shrink();
        }),
        EmSearchPill(color: EmColors.background, fieldKey: const Key('new_picker_search'), hint: 'Search by name or roll number', onChanged: (v) => p.query.value = v),
        const SizedBox(height: EmSpacing.s12),
        Expanded(
          child: Obx(() {
            final st = p.state;
            final list = p.visible;
            final q = p.query.value;
            switch (st.status) {
              case SectionStatus.loading:
                return AppShimmer(key: const Key('new_picker_loading'), child: Column(children: List.generate(5, (_) => const ShimmerListRowSkeleton())));
              case SectionStatus.error:
                return AppErrorView(message: st.message ?? 'Something went wrong', onRetry: () => p.load(force: true));
              case SectionStatus.forbidden:
                return const AppEmptyView(icon: Icons.lock_outline_rounded, title: "You don't have access");
              case SectionStatus.unavailable:
                return const AppEmptyView(icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
              case SectionStatus.empty:
                return const AppEmptyView(key: Key('new_picker_empty'), icon: Icons.groups_outlined, title: 'No students in this class');
              case SectionStatus.data:
                if (list.isEmpty) return AppEmptyView(icon: Icons.search_off_rounded, title: 'No student matches "$q"');
                return ListView(children: [
                  for (final s in list)
                    StudentTile(
                      student: s,
                      onTap: () {
                        controller.selectStudent(s);
                        Navigator.of(context).pop();
                      },
                    ),
                ]);
            }
          }),
        ),
      ]),
    );
  }
}
