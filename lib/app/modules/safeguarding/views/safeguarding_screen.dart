import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/safeguarding/safeguarding_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../common/action_failure.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/safeguarding_controller.dart';

const kSafeguardingNotice = "This goes confidentially to your school's safeguarding lead. It is not shared with parents. If a child is in immediate danger contact the emergency services or your safeguarding lead directly.";

/// Raise a concern (`/safeguarding`). Write-only: after sending there is only a "Report sent" view, never a case list or details.
class SafeguardingScreen extends GetView<SafeguardingController> {
  const SafeguardingScreen({super.key});
  SafeguardingController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.sent.value) return _SentView(reference: c.reference.value);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || c.sending.value) return;
          if (c.isDirty) {
            final leave = await ConfirmDialog.show(title: 'Discard this concern?', message: 'What you wrote will be lost. Nothing has been sent.', confirmLabel: 'Discard', cancelLabel: 'Keep writing', destructive: true);
            if (!leave) return;
          }
          Get.back();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Raise a concern')),
          body: Column(children: [Expanded(child: _form(context)), _bottom(context)]),
        ),
      );
    });
  }

  Widget _form(BuildContext context) {
    final errors = c.errors;
    final failure = c.failure.value;
    final student = c.student.value;
    final type = c.type.value;
    final day = c.day.value;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          key: const Key('sg_notice'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryColorLight.withOpacity(0.4))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 20, color: AppColors.primaryColor),
            SizedBox(width: 10),
            Expanded(child: CustomText(text: kSafeguardingNotice, fontSize: 12.5, color: AppColors.primaryColor, fontWeight: FontWeight.w600, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 14),
        if (failure != null) ErrorBanner(bannerKey: const Key('sg_submit_error'), message: _failureText(failure)),
        FormLabel('Who is this about?', error: errors['student']),
        InkWell(
          key: const Key('sg_student_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _pickStudent(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: errors['student'] == null ? AppColors.line : AppColors.redText)),
            child: Row(children: [
              if (student != null) ...[StudentAvatar(student: student, size: 34), const SizedBox(width: 10)] else const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.person_search_rounded, color: AppColors.primaryColor)),
              Expanded(
                child: student == null
                    ? const CustomText(key: Key('sg_no_student'), text: 'Not about a specific student (tap to choose one)', color: AppColors.muted, fontSize: 13)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CustomText(key: const Key('sg_selected_student'), text: student.fullName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13),
                        CustomText(text: student.grade.isEmpty ? '' : '${student.grade}${student.section.isEmpty ? '' : ' - ${student.section}'}', color: AppColors.muted, fontSize: 11),
                      ]),
              ),
              if (student != null) IconButton(key: const Key('sg_clear_student'), visualDensity: VisualDensity.compact, onPressed: c.clearStudent, icon: const Icon(Icons.close_rounded, size: 18)) else const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        FormLabel('What kind of concern? *', error: errors['type']),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in ConcernType.values)
            InkWell(
              key: Key('sg_type_${t.wire}'),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => c.setType(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: type == t ? AppColors.primaryColor : Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: type == t ? AppColors.primaryColor : AppColors.line)),
                child: CustomText(text: t.label, color: type == t ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        LabeledField(label: 'Short summary', required: true, controller: c.titleC, fieldKey: const Key('sg_title'), hint: 'A few words', maxLength: kConcernTitleMax, error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'What happened', required: true, controller: c.descriptionC, fieldKey: const Key('sg_description'), maxLines: 6, maxLength: kConcernTextMax, hint: 'What you saw or heard, where and when. Stick to facts.', error: errors['description'], onChanged: (_) => c.errors.remove('description')),
        LabeledField(label: 'Immediate action you took (optional)', controller: c.actionsC, fieldKey: const Key('sg_actions'), maxLines: 3, maxLength: kConcernTextMax, hint: 'For example: spoke to the child, informed a colleague'),
        const FormLabel('How serious does it seem?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in ConcernSeverity.values)
            ChoiceChip(key: Key('sg_sev_${s.wire}'), label: Text(s.label), selected: c.severity.value == s, onSelected: (_) => c.setSeverity(s)),
        ]),
        const SizedBox(height: 14),
        const FormLabel('When did it happen?'),
        InkWell(
          key: const Key('sg_date_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: day, firstDate: today.subtract(const Duration(days: 365)), lastDate: today);
            if (picked != null) c.setDay(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
            child: Row(children: [
              const Icon(Icons.event_rounded, size: 18, color: AppColors.primaryColor),
              const SizedBox(width: 10),
              CustomText(text: '${shortDay(day)} ${day.year}${day == c.today ? ' (today)' : ''}', fontWeight: FontWeight.w700, fontSize: 13),
            ]),
          ),
        ),
      ],
    );
  }

  String _failureText(ActionFailure f) => f.kind == ActionFailureKind.forbidden ? "You don't have access to raise a concern here. Speak to your safeguarding lead directly." : f.message;

  Widget _bottom(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('sg_submit'),
            onPressed: c.sending.value ? null : () => _submit(context),
            child: c.sending.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'Send report', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (c.sending.value) return;
    final problems = c.validate();
    if (problems.isNotEmpty) {
      c.errors.assignAll(problems);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problems.values.first), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 90)));
      return;
    }
    final ok = await ConfirmDialog.show(
      title: 'Send this concern?',
      message: "It goes confidentially to your school's safeguarding lead and cannot be edited or withdrawn from the app afterwards.",
      confirmLabel: 'Send',
      cancelLabel: 'Keep editing',
    );
    if (!ok) return;
    await c.submit();
  }

  Future<void> _pickStudent(BuildContext context) async {
    c.loadPickerClass();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.85, child: _PickerSheet(controller: c)),
    );
  }
}

class _SentView extends StatelessWidget {
  final String? reference;
  const _SentView({this.reference});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raise a concern'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.greenBg, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 40, color: AppColors.greenText)),
          const SizedBox(height: 16),
          const CustomText(key: Key('sg_sent_title'), text: 'Report sent', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          if (reference != null) Padding(padding: const EdgeInsets.only(top: 8), child: CustomText(key: const Key('sg_reference'), text: 'Reference: $reference', fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const CustomText(text: "Your concern was recorded for your school's safeguarding lead. It is not shared with parents. If the child is in immediate danger, contact the emergency services or your safeguarding lead directly.", fontSize: 13, color: AppColors.muted, height: 1.45, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(key: const Key('sg_done'), onPressed: () => Get.back(), child: const CustomText(text: 'Done', color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final SafeguardingController controller;
  const _PickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CustomText(text: 'Choose a student', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
        const SizedBox(height: 4),
        const CustomText(text: 'Only students of your classes are listed.', fontSize: 11.5, color: AppColors.muted),
        const SizedBox(height: 10),
        Obx(() {
          final cs = c.classes;
          final sel = c.pickerClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: 10), child: ClassPicker(classes: cs, selected: sel, onSelect: c.selectPickerClass)) : const SizedBox.shrink();
        }),
        TextField(
          key: const Key('sg_picker_search'),
          onChanged: (v) => c.pickerQuery.value = v,
          decoration: InputDecoration(isDense: true, hintText: 'Search by name or roll number', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.pale, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Obx(() {
            final st = c.pickerState;
            final list = c.pickerVisible;
            final q = c.pickerQuery.value;
            if (c.classes.isEmpty) return const AppEmptyView(key: Key('picker_no_classes'), icon: Icons.school_outlined, title: "You aren't assigned to any class yet", subtitle: 'You can still report a concern that is not about a specific student.');
            switch (st.status) {
              case SectionStatus.loading:
                return AppShimmer(key: const Key('picker_loading'), child: Column(children: List.generate(5, (_) => const ShimmerListRowSkeleton())));
              case SectionStatus.error:
                return AppErrorView(message: st.message ?? 'Something went wrong', onRetry: () => c.loadPickerClass(force: true));
              case SectionStatus.forbidden:
                return const AppEmptyView(key: Key('picker_forbidden'), icon: Icons.lock_outline_rounded, title: "You don't have access");
              case SectionStatus.unavailable:
                return const AppEmptyView(icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
              case SectionStatus.empty:
                return const AppEmptyView(key: Key('picker_empty'), icon: Icons.groups_outlined, title: 'No students in this class');
              case SectionStatus.data:
                if (list.isEmpty) return AppEmptyView(key: const Key('picker_search_empty'), icon: Icons.search_off_rounded, title: 'No student matches "$q"');
                return ListView(children: [
                  for (final s in list)
                    StudentTile(
                      student: s,
                      onTap: () {
                        c.selectStudent(s);
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
