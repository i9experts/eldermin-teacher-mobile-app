import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../controllers/observation_form_controller.dart';
import '../controllers/ey_submit.dart';
import 'widgets/early_years_widgets.dart';
import 'widgets/ey_form_widgets.dart';

/// Full observation (`/early-years/child/:id/observe`): what you saw, optional skill and level, photos, and a share switch that is OFF by default.
class ObservationFormScreen extends GetView<ObservationFormController> {
  const ObservationFormScreen({super.key});

  ObservationFormController get c => controller;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this observation?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'New observation'),
        body: Obx(() {
          final blocked = c.blocked;
          if (blocked != null) return EyBlockedView(message: blocked);
          return Column(children: [Expanded(child: _form(context)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final failure = c.failure.value;
    final errors = c.errors;
    final k = c.child;
    final refs = c.refs.value;
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EmInfoBanner(key: const Key('ey_submit_error'), tone: EmTone.error, text: failure.message)),
        if (k != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EceChildTile(child: k)),
        eyField(label: 'What did you observe *', controller: c.narrativeC, fieldKey: const Key('ey_obs_narrative'), maxLines: 5, hint: 'Describe it briefly and factually', error: errors['narrative'], onChanged: (_) => c.errors.remove('narrative')),
        const EyLabel('Type'),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final e in kObservationTypes.entries) EmChip(key: Key('ey_type_${e.key}'), label: e.value, selected: c.type.value == e.key, onTap: () => c.setType(e.key)),
        ]),
        const SizedBox(height: EmSpacing.block),
        eyField(label: 'Next step', controller: c.nextStepC, fieldKey: const Key('ey_obs_next'), maxLines: 2, hint: 'What could come next for this child'),
        if (refs.status == SectionStatus.data) ...[
          Row(children: [
            Expanded(child: Text('Link to a skill (optional)', style: EmType.label.copyWith(color: EmColors.textSecondary))),
            if (c.skillId.value != null || c.level.value != null) TextButton(key: const Key('ey_skill_clear'), onPressed: c.clearSkill, child: Text('Clear', style: EmType.label.copyWith(color: EmColors.primary))),
          ]),
          const SizedBox(height: EmSpacing.s8),
          EySkillPicker(
            refs: refs.data!,
            domainId: c.domainId.value,
            skillId: c.skillId.value,
            level: c.level.value,
            onDomain: c.setDomain,
            onSkill: c.setSkill,
            onLevel: c.setLevel,
            skillError: errors['skill'],
            required: false,
          ),
        ],
        EyPhotosSection(photos: c.photos, error: errors['photos']),
        Obx(() => EyShareSwitch(value: c.share.value, onChanged: c.setShare, note: c.share.value ? 'Parents will see this observation in their app.' : 'Off: only staff can see it.')),
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
          child: Obx(() => EmPrimaryButton(key: const Key('ey_obs_submit'), loading: c.saving.value, label: 'Save observation', onPressed: c.saving.value ? null : () => _submit(context))),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    // validate first so a confirm is never shown for a form that would not be saved anyway
    final problems = c.validate();
    if (problems.isEmpty && c.needsShareConfirm) {
      final ok = await ConfirmDialog.show(title: ObservationFormController.shareConfirmTitle, message: ObservationFormController.shareConfirmMessage, confirmLabel: 'Share and save', cancelLabel: 'Go back');
      if (!ok) return;
    }
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case EySaved<EceObservation>():
        ToastUtil.showToast('Observation saved');
        Get.back();
      case EyInvalid<EceObservation>():
        _snack(context, r.errors.values.first);
      case EyFailed<EceObservation>(:final failure):
        _snack(context, failure.message);
      case EyIgnored<EceObservation>():
        break;
    }
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), margin: EmSpacing.snackAboveBar));
}
