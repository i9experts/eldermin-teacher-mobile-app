import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/messaging/chat_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../common/action_failure.dart';
import '../../../routes/app_routes.dart';
import '../../behaviour/views/widgets/behaviour_widgets.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../home/models/section_state.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/new_thread_controller.dart';

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
      child: Scaffold(
        appBar: AppBar(title: const CustomText(text: 'New message', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('new_submit_error'), message: _failureText(failure)),
        FormLabel('Student *', error: errors['student']),
        InkWell(
          key: const Key('new_student_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _pickStudent(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: errors['student'] == null ? AppColors.line : AppColors.redText)),
            child: Row(children: [
              if (student != null) ...[StudentAvatar(student: student, size: 34), const SizedBox(width: 10)] else const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.person_search_rounded, color: AppColors.primaryColor)),
              Expanded(
                child: student == null
                    ? const CustomText(text: 'Choose a student from your classes', color: AppColors.faint, fontSize: 13)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CustomText(key: const Key('new_selected_student'), text: student.fullName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13),
                        CustomText(text: student.classLabel, color: AppColors.muted, fontSize: 11),
                      ]),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (student != null) ...[
          FormLabel('Guardian *', error: errors['guardian']),
          _guardians(),
          const SizedBox(height: 6),
          const ParentVisibleNote(text: 'You message guardians inside the app. Their phone number and email are not shown to you.'),
          const SizedBox(height: 14),
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
        return const AppCard(key: Key('new_guardians_empty'), child: CustomText(text: 'No guardian account is registered for this student, so there is nobody to message in the app.', color: AppColors.muted, fontSize: 12));
      case SectionStatus.data:
        final sel = c.guardian.value;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in st.data!)
            ChoiceChip(
              key: Key('guardian_${g.userId}'),
              label: Text(g.display),
              selected: sel?.userId == g.userId,
              onSelected: (_) => c.selectGuardian(g),
            ),
        ]);
    }
  }

  Widget _bottom(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: SizedBox(
          width: double.infinity,
          child: Obx(() => ElevatedButton(
                key: const Key('new_submit'),
                onPressed: c.saving.value ? null : () => _submit(context),
                child: c.saving.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const CustomText(text: 'Send message', color: Colors.white, fontWeight: FontWeight.w700),
              )),
        ),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.85, child: _PickerSheet(controller: c)),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final NewThreadController controller;
  const _PickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = controller.picker;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CustomText(text: 'Choose a student', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
        const SizedBox(height: 10),
        Obx(() {
          final cs = p.classes;
          final sel = p.selectedClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: 10), child: ClassPicker(classes: cs, selected: sel, onSelect: p.selectClass)) : const SizedBox.shrink();
        }),
        TextField(
          key: const Key('new_picker_search'),
          onChanged: (v) => p.query.value = v,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name or roll number',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.pale,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
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
