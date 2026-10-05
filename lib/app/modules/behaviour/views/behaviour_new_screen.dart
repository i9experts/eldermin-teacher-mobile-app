import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/behaviour_log_controller.dart';
import 'widgets/behaviour_widgets.dart';

/// Quick log (`/behaviour/new`): merit / demerit / note for a student of MY classes.
class BehaviourNewScreen extends GetView<BehaviourLogController> {
  const BehaviourNewScreen({super.key});

  BehaviourLogController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 90)));

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
      child: Scaffold(
        appBar: AppBar(title: const CustomText(text: 'Log behaviour', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('beh_submit_error'), message: failure.message),
        SegmentedControl(
          options: [for (final k in BehaviourKind.values) k.label],
          selectedIndex: BehaviourKind.values.indexOf(kind),
          onChanged: (i) => c.setKind(BehaviourKind.values[i]),
        ),
        const SizedBox(height: 14),
        FormLabel('Student *', error: errors['student']),
        InkWell(
          key: const Key('beh_student_picker'),
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
                        CustomText(key: const Key('beh_selected_student'), text: student.fullName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13),
                        CustomText(text: [if (student.grade.isNotEmpty) '${student.grade}${student.section.isEmpty ? '' : ' - ${student.section}'}', if ((student.rollNumber ?? '').isNotEmpty) 'Roll ${student.rollNumber}'].join(' · '), color: AppColors.muted, fontSize: 11),
                      ]),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        FormLabel('Category *', error: errors['category']),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in c.categories)
            InkWell(
              key: Key('cat_$k'),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => c.setCategory(k),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cat == k ? kindColor(kind) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: cat == k ? kindColor(kind) : AppColors.line),
                ),
                child: CustomText(text: categoryLabel(k), color: cat == k ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 11.5),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        LabeledField(label: 'Title', required: true, controller: c.titleC, fieldKey: const Key('beh_title'), hint: 'Short summary', error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        LabeledField(label: 'What happened', required: true, controller: c.descriptionC, fieldKey: const Key('beh_description'), maxLines: 4, hint: 'Describe it briefly and factually', error: errors['description'], onChanged: (_) => c.errors.remove('description')),
        if (kind == BehaviourKind.demerit) ...[
          const FormLabel('Severity'),
          ChoiceWrap(labels: const ['low', 'medium', 'high', 'critical'], selected: sev, onSelect: c.setSeverity, keyPrefix: 'sev_'),
          const SizedBox(height: 14),
        ],
        if (kind != BehaviourKind.note) ...[
          FormLabel(kind == BehaviourKind.merit ? 'Merit points' : 'Demerit points'),
          Wrap(spacing: 8, children: [
            for (final m in BehaviourLogController.pointChoices)
              ChoiceChip(
                key: Key('pts_$m'),
                label: Text(kind == BehaviourKind.merit ? '+$m' : '-$m'),
                selected: mag == m,
                onSelected: (_) => c.setMagnitude(m),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        const FormLabel('Date'),
        InkWell(
          key: const Key('beh_date_picker'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final today = c.today;
            final picked = await showAppDatePicker(context, initialDate: day, firstDate: today.subtract(const Duration(days: 90)), lastDate: today);
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
        const SizedBox(height: 14),
        const ParentVisibleNote(text: "Parents can see this entry in their app as soon as you save it. Keep it factual and respectful. For safeguarding concerns use \"Raise a concern\" in More."),
      ],
    );
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
                key: const Key('beh_submit'),
                onPressed: c.saving.value ? null : () => _submit(context),
                child: c.saving.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : CustomText(text: 'Save ${c.kind.value.label.toLowerCase()}', color: Colors.white, fontWeight: FontWeight.w700),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.85, child: _PickerSheet(controller: c)),
    );
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CustomText(text: 'Choose a student', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
        const SizedBox(height: 10),
        Obx(() {
          final cs = c.classes;
          final sel = c.pickerClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: 10), child: ClassPicker(classes: cs, selected: sel, onSelect: c.selectPickerClass)) : const SizedBox.shrink();
        }),
        TextField(
          key: const Key('beh_picker_search'),
          onChanged: (v) => c.pickerQuery.value = v,
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
