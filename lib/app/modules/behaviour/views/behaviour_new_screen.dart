import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/behaviour_log_controller.dart';
import 'widgets/behaviour_widgets.dart';
import '../../../../core/design/design.dart';

/// Quick log (`/behaviour/new`): merit / demerit / note for a student of MY classes.
class BehaviourNewScreen extends GetView<BehaviourLogController> {
  const BehaviourNewScreen({super.key});

  BehaviourLogController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), margin: EmSpacing.snackAboveBar));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this entry?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'Log behaviour'),
        body: Obx(() {
          if (!c.canLog) {
            return const AppEmptyView(key: Key('beh_no_access'), icon: Icons.lock_outline_rounded, title: "You don't have access", subtitle: "Your account isn't allowed to log behaviour. Ask your school admin if you think this is a mistake.");
          }
          if (c.classes.isEmpty) {
            return const AppEmptyView(key: Key('beh_no_classes'), icon: Icons.school_outlined, title: "You aren't assigned to any class yet", subtitle: 'Behaviour is logged for the students of your classes.');
          }
          return Column(children: [Expanded(child: _form(context)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final kind = c.kind.value;
    final errors = c.errors;
    final failure = c.failure.value;
    final student = c.student.value;
    final cat = c.category.value;
    final day = c.day.value;
    final sev = c.severity.value;
    final mag = c.magnitude.value;
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('beh_submit_error'), message: failure.message),
        EmSegmentedTabs<BehaviourKind>(
          segments: [for (final k in BehaviourKind.values) EmSegment(k, k.label)],
          selected: kind,
          onChanged: c.setKind,
        ),
        const SizedBox(height: EmSpacing.block),
        FormLabel('Student *', error: errors['student']),
        KeyedSubtree(
          key: const Key('beh_student_picker'),
          child: EmSelectField(
            leading: student == null ? const ExcludeSemantics(child: Icon(Icons.person_search_rounded, color: EmColors.primary)) : StudentAvatar(student: student, size: 36),
            title: student?.fullName,
            titleKey: const Key('beh_selected_student'),
            subtitle: student == null ? null : [if (student.grade.isNotEmpty) '${student.grade}${student.section.isEmpty ? '' : ' - ${student.section}'}', if ((student.rollNumber ?? '').isNotEmpty) 'Roll ${student.rollNumber}'].join(' · '),
            placeholder: 'Choose a student from your classes',
            hasError: errors['student'] != null,
            onTap: () => _pickStudent(context),
          ),
        ),
        const SizedBox(height: EmSpacing.block),
        FormLabel('Category *', error: errors['category']),
        Wrap(spacing: EmSpacing.s8, children: [
          for (final k in c.categories) EmChip(key: Key('cat_$k'), label: categoryLabel(k), selected: cat == k, onTap: () => c.setCategory(k)),
        ]),
        const SizedBox(height: EmSpacing.s8),
        LabeledField(label: 'Title', required: true, controller: c.titleC, fieldKey: const Key('beh_title'), hint: 'Short summary', error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'What happened', required: true, controller: c.descriptionC, fieldKey: const Key('beh_description'), maxLines: 4, hint: 'Describe it briefly and factually', error: errors['description'], onChanged: (_) => c.errors.remove('description')),
        if (kind == BehaviourKind.demerit) ...[
          const FormLabel('Severity'),
          ChoiceWrap(labels: const ['low', 'medium', 'high', 'critical'], selected: sev, onSelect: c.setSeverity, keyPrefix: 'sev_'),
          const SizedBox(height: EmSpacing.block),
        ],
        if (kind != BehaviourKind.note) ...[
          FormLabel(kind == BehaviourKind.merit ? 'Merit points' : 'Demerit points'),
          Wrap(spacing: EmSpacing.s8, children: [
            for (final m in BehaviourLogController.pointChoices) EmChip(key: Key('pts_$m'), label: kind == BehaviourKind.merit ? '+$m' : '-$m', selected: mag == m, onTap: () => c.setMagnitude(m)),
          ]),
          const SizedBox(height: EmSpacing.block),
        ],
        const FormLabel('Date'),
        KeyedSubtree(
          key: const Key('beh_date_picker'),
          child: EmSelectField(
            icon: Icons.event_rounded,
            trailingIcon: null,
            title: '${shortDay(day)} ${day.year}${day == c.today ? ' (today)' : ''}',
            onTap: () async {
              final today = c.today;
              final picked = await showAppDatePicker(context, initialDate: day, firstDate: today.subtract(const Duration(days: 90)), lastDate: today);
              if (picked != null) c.setDay(picked);
            },
          ),
        ),
        const SizedBox(height: EmSpacing.block),
        const ParentVisibleNote(text: "Parents can see this entry in their app as soon as you save it. Keep it factual and respectful. For safeguarding concerns use \"Raise a concern\" in More."),
      ],
    );
  }

  Widget _bottom(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s12),
          child: Obx(() => EmPrimaryButton(
                key: const Key('beh_submit'),
                loading: c.saving.value,
                label: 'Save ${c.kind.value.label.toLowerCase()}',
                onPressed: c.saving.value ? null : () => _submit(context),
              )),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case LogSaved():
        ToastUtil.showToast('${c.kind.value.label} saved');
        Get.back();
      case LogInvalid():
        _snack(context, r.errors.values.first);
      case LogFailed(:final failure):
        _snack(context, failure.message);
      case LogIgnored():
        break;
    }
  }

  Future<void> _pickStudent(BuildContext context) async {
    await EmBottomSheet.showPanel<void>(context, heightFactor: 0.85, builder: (_) => _PickerSheet(controller: c));
  }
}

/// Student picker: class chips (MY classes) + search + the roster of the chosen class.
class _PickerSheet extends StatelessWidget {
  final BehaviourLogController controller;
  const _PickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose a student', style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.row),
        Obx(() {
          final cs = c.classes;
          final sel = c.pickerClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: EmSpacing.row), child: ClassPicker(classes: cs, selected: sel, onSelect: c.selectPickerClass)) : const SizedBox.shrink();
        }),
        EmSearchPill(fieldKey: const Key('beh_picker_search'), hint: 'Search by name or roll number', onChanged: (v) => c.pickerQuery.value = v),
        const SizedBox(height: EmSpacing.row),
        Expanded(
          child: Obx(() {
            final st = c.pickerState;
            final list = c.pickerVisible;
            final q = c.pickerQuery.value;
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
