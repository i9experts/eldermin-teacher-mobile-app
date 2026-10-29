import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/tarbiyah_form_controller.dart';
import '../../../../core/design/design.dart';

/// Tarbiyah assessment form (`/behaviour/tarbiyah/form`): create one for a student of my classes, or edit one I recorded (decision D3).
/// Needs [TarbiyahFormArgs] in the route arguments; without them (a stale link) it says so instead of opening an empty form.
class TarbiyahFormScreen extends StatelessWidget {
  const TarbiyahFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TarbiyahFormController>()) {
      return EmScaffold(
        appBar: EmAppBar(title: 'Assessment'),
        body: const AppEmptyView(key: Key('tarbiyah_no_student'), icon: Icons.person_search_rounded, title: 'Open a student first', subtitle: "Assessments are written from a student's behaviour page."),
      );
    }
    return const _Form();
  }
}

class _Form extends GetView<TarbiyahFormController> {
  const _Form();

  TarbiyahFormController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), margin: EmSpacing.snackAboveBar));

  @override
  Widget build(BuildContext context) {
    final label = c.settings.programName;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this assessment?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: c.isEditing ? 'Edit $label assessment' : 'New $label assessment'),
        body: Obx(() {
          if (!c.canWrite) {
            return const AppEmptyView(key: Key('tarbiyah_no_access'), icon: Icons.lock_outline_rounded, title: "You don't have access", subtitle: "Your account isn't allowed to write assessments. Ask your school admin if you think this is a mistake.");
          }
          if (!c.mayEditThis) {
            return const AppEmptyView(key: Key('tarbiyah_not_author'), icon: Icons.lock_outline_rounded, title: "You can't edit this assessment", subtitle: 'Only the teacher who recorded it, or an administrator, can edit it.');
          }
          return Column(children: [Expanded(child: _body(context)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final errors = c.errors;
    final failure = c.failure.value;
    final type = c.periodType.value;
    final day = c.day.value;
    final avg = c.previewAverage;
    final s = c.student;
    // read so the form rebuilds when a score changes
    c.scores.length;
    final scores = Map<String, int>.of(c.scores);
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) ErrorBanner(bannerKey: const Key('tarbiyah_submit_error'), message: failure.message),
        Text(s.fullName, key: const Key('tarbiyah_student'), style: EmType.title.copyWith(color: EmColors.ink)),
        EmCaptionLine([if (s.grade.isNotEmpty) '${s.grade}${s.section.isEmpty ? '' : ' - ${s.section}'}', if ((s.rollNumber ?? '').isNotEmpty) 'Roll ${s.rollNumber}'].join(' · ')),
        const SizedBox(height: EmSpacing.block),
        const FormLabel('Period type'),
        Wrap(spacing: EmSpacing.s8, children: [
          for (final t in kTarbiyahPeriodTypes) EmChip(key: Key('tarbiyah_type_$t'), label: tarbiyahPeriodTypeLabel(t), selected: type == t, onTap: () => c.setPeriodType(t)),
        ]),
        const SizedBox(height: EmSpacing.s8),
        LabeledField(
          label: 'Period',
          required: true,
          controller: c.periodC,
          fieldKey: const Key('tarbiyah_period'),
          hint: 'e.g. Term 1 2025-26 or Monthly 2025-02',
          error: errors['period'],
          onChanged: (_) => c.errors.remove('period'),
        ),
        const FormLabel('Assessment date'),
        KeyedSubtree(
          key: const Key('tarbiyah_date_picker'),
          child: EmSelectField(
            icon: Icons.event_rounded,
            trailingIcon: null,
            title: '${shortDay(day)} ${day.year}${day == c.today ? ' (today)' : ''}',
            hasError: errors['day'] != null,
            onTap: () async {
              final today = c.today;
              final picked = await showAppDatePicker(context, initialDate: day, firstDate: today.subtract(const Duration(days: 400)), lastDate: today);
              if (picked != null) c.setDay(picked);
            },
          ),
        ),
        if (errors['day'] != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(errors['day']!, style: EmType.caption.copyWith(color: EmColors.error))),
        const SizedBox(height: EmSpacing.block),
        FormLabel('Traits (${c.scaleMin} to ${c.scaleMax})', error: errors['traits']),
        for (final k in c.traitKeys)
          Padding(
            key: ValueKey('tarbiyah_trait_$k'),
            padding: const EdgeInsets.only(bottom: EmSpacing.row),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.settings.labelFor(k), style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: EmSpacing.s4),
              Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
                for (final v in c.scaleChoices) EmChip(key: Key('score_${k}_$v'), label: '$v', selected: scores[k] == v, onTap: () => c.setScore(k, v)),
              ]),
            ]),
          ),
        if (avg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: EmSpacing.row),
            child: Text('Average so far: ${avg.toStringAsFixed(1)} of ${c.scaleMax} (${scores.length} ${scores.length == 1 ? 'trait' : 'traits'}). The overall rating is calculated when you save.',
                key: const Key('tarbiyah_average'), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ),
        LabeledField(label: 'Teacher observations', controller: c.observationsC, fieldKey: const Key('tarbiyah_observations'), maxLines: 4, hint: 'What you have noticed this period', error: errors['observations'], onChanged: (_) => c.errors.remove('observations')),
        LabeledField(label: 'Strengths', controller: c.strengthsC, fieldKey: const Key('tarbiyah_strengths'), maxLines: 3, hint: 'One per line'),
        LabeledField(label: 'Areas to improve', controller: c.improvementsC, fieldKey: const Key('tarbiyah_improvements'), maxLines: 3, hint: 'One per line'),
        const SizedBox(height: EmSpacing.s8),
        const EmInfoBanner(
          key: Key('tarbiyah_visibility_note'),
          tone: EmTone.info,
          icon: Icons.visibility_off_outlined,
          text: 'This assessment is for school staff. You can edit it later; only you or an administrator can.',
        ),
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
                key: const Key('tarbiyah_submit'),
                loading: c.saving.value,
                label: c.isEditing ? 'Save changes' : 'Save assessment',
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
      case TarbiyahSaved():
        ToastUtil.showToast(c.isEditing ? 'Assessment updated' : 'Assessment saved');
        Get.back();
      case TarbiyahInvalid():
        _snack(context, r.errors.values.first);
      case TarbiyahFailed(:final failure):
        _snack(context, failure.message);
      case TarbiyahIgnored():
        break;
    }
  }
}
