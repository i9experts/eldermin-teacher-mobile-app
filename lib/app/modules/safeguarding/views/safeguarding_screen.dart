import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/safeguarding/safeguarding_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart' show AppEmptyView, AppErrorView;
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../common/action_failure.dart';
import '../../../components/confirm_dialog.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/safeguarding_controller.dart';
import '../../../../core/design/design.dart';

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
        child: EmScaffold(
          appBar: EmAppBar(title: 'Raise a concern'),
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
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
      children: [
        EmInfoBanner(key: const Key('sg_notice'), tone: EmTone.info, icon: Icons.shield_outlined, text: kSafeguardingNotice),
        const SizedBox(height: EmSpacing.s4),
        const SizedBox(height: EmSpacing.s8),
        if (failure != null) ErrorBanner(bannerKey: const Key('sg_submit_error'), message: _failureText(failure)),
        FormLabel('Who is this about?', error: errors['student']),
        InkWell(
          key: const Key('sg_student_picker'),
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
                    ? Text('Not about a specific student (tap to choose one)', key: const Key('sg_no_student'), style: EmType.label.copyWith(color: EmColors.textSecondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(student.fullName, key: const Key('sg_selected_student'), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.primary)),
                        Text(student.grade.isEmpty ? '' : '${student.grade}${student.section.isEmpty ? '' : ' - ${student.section}'}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                      ]),
              ),
              if (student != null) EmIconCircleButton(key: const Key('sg_clear_student'), icon: Icons.close_rounded, semanticLabel: 'Clear the student', tooltip: 'Clear the student', onTap: c.clearStudent) else const Icon(Icons.expand_more_rounded, color: EmColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: EmSpacing.block),
        FormLabel('What kind of concern? *', error: errors['type']),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final t in ConcernType.values) EmChip(key: Key('sg_type_${t.wire}'), label: t.label, icon: type == t ? Icons.check_rounded : null, selected: type == t, onTap: () => c.setType(t)),
        ]),
        const SizedBox(height: EmSpacing.block),
        LabeledField(label: 'Short summary', required: true, controller: c.titleC, fieldKey: const Key('sg_title'), hint: 'A few words', maxLength: kConcernTitleMax, error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'What happened', required: true, controller: c.descriptionC, fieldKey: const Key('sg_description'), maxLines: 6, maxLength: kConcernTextMax, hint: 'What you saw or heard, where and when. Stick to facts.', error: errors['description'], onChanged: (_) => c.errors.remove('description')),
        LabeledField(label: 'Immediate action you took (optional)', controller: c.actionsC, fieldKey: const Key('sg_actions'), maxLines: 3, maxLength: kConcernTextMax, hint: 'For example: spoke to the child, informed a colleague'),
        const FormLabel('How serious does it seem?'),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final s in ConcernSeverity.values) EmChip(key: Key('sg_sev_${s.wire}'), label: s.label, icon: c.severity.value == s ? Icons.check_rounded : null, selected: c.severity.value == s, onTap: () => c.setSeverity(s)),
        ]),
        const SizedBox(height: EmSpacing.block),
        const FormLabel('When did it happen?'),
        InkWell(
          key: const Key('sg_date_picker'),
          borderRadius: EmRadius.mdAll,
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: day, firstDate: today.subtract(const Duration(days: 365)), lastDate: today);
            if (picked != null) c.setDay(picked);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s12),
            decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: EmColors.border)),
            child: Row(children: [
              const ExcludeSemantics(child: Icon(Icons.event_rounded, size: 20, color: EmColors.primary)),
              const SizedBox(width: EmSpacing.s12),
              Expanded(child: Text('${shortDay(day)} ${day.year}${day == c.today ? ' (today)' : ''}', style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink))),
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
        padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
        decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
        child: EmPrimaryButton(key: const Key('sg_submit'), label: 'Send report', loading: c.sending.value, onPressed: c.sending.value ? null : () => _submit(context)),
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
        ..showSnackBar(SnackBar(content: Text(problems.values.first), behavior: SnackBarBehavior.floating, margin: EmSpacing.snackAboveBar));
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
    await EmBottomSheet.showPanel<void>(context, heightFactor: 0.85, builder: (_) => _PickerSheet(controller: c));
  }
}

class _SentView extends StatelessWidget {
  final String? reference;
  const _SentView({this.reference});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Raise a concern', showBack: false),
      body: Padding(
        padding: const EdgeInsets.all(EmSpacing.s24),
        child: SingleChildScrollView(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: EmTone.success.background, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 40, color: EmTone.success.foreground)),
            const SizedBox(height: EmSpacing.s16),
            Text('Report sent', key: const Key('sg_sent_title'), style: EmType.title.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink)),
            if (reference != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('Reference: $reference', key: const Key('sg_reference'), style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w700))),
            const SizedBox(height: EmSpacing.s12),
            Text("Your concern was recorded for your school's safeguarding lead. It is not shared with parents. If the child is in immediate danger, contact the emergency services or your safeguarding lead directly.", textAlign: TextAlign.center, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.45)),
            const SizedBox(height: EmSpacing.s24),
            EmPrimaryButton(key: const Key('sg_done'), label: 'Done', onPressed: () => Get.back()),
          ]),
        ),
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
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose a student', style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s4),
        Text('Only students of your classes are listed.', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        const SizedBox(height: EmSpacing.s12),
        Obx(() {
          final cs = c.classes;
          final sel = c.pickerClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s12), child: ClassPicker(classes: cs, selected: sel, onSelect: c.selectPickerClass)) : const SizedBox.shrink();
        }),
        EmSearchPill(color: EmColors.background, fieldKey: const Key('sg_picker_search'), hint: 'Search by name or roll number', onChanged: (v) => c.pickerQuery.value = v),
        const SizedBox(height: EmSpacing.s12),
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
