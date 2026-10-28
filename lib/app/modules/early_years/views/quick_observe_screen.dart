import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../controllers/ey_submit.dart';
import '../controllers/quick_observe_controller.dart';
import 'widgets/early_years_widgets.dart';
import 'widgets/ey_form_widgets.dart';

/// Quick observation (`/early-years/child/:id/quick`): a skill, a level and optionally a line of text, in a few taps.
class QuickObserveScreen extends GetView<QuickObserveController> {
  const QuickObserveScreen({super.key});

  QuickObserveController get c => controller;

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
        appBar: EmAppBar(title: 'Quick observation'),
        body: Obx(() {
          final blocked = c.blocked;
          if (blocked != null) return EyBlockedView(message: blocked);
          final refs = c.refs.value;
          if (refs.status != SectionStatus.data) {
            return ScreenStateView<EyRefs>(
              state: refs,
              onRefresh: c.loadRefs,
              onRetry: c.loadRefs,
              emptyIcon: Icons.psychology_alt_outlined,
              emptyTitle: 'No skills are set up yet',
              emptySubtitle: 'Ask your school admin to set up the Early Years skills.',
              builder: (_) => const [],
            );
          }
          return Column(children: [Expanded(child: _form(context, refs.data!)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context, EyRefs refs) {
    final failure = c.failure.value;
    final errors = c.errors;
    final k = c.child;
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EmInfoBanner(key: const Key('ey_submit_error'), tone: EmTone.error, text: failure.message)),
        if (k != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EceChildTile(child: k)),
        EySkillPicker(
          refs: refs,
          domainId: c.domainId.value,
          skillId: c.skillId.value,
          level: c.level.value,
          onDomain: c.setDomain,
          onSkill: c.setSkill,
          onLevel: c.setLevel,
          skillError: errors['skill'],
          levelError: errors['level'],
        ),
        eyField(label: 'Note (optional)', controller: c.narrativeC, fieldKey: const Key('ey_quick_note'), maxLines: 3, hint: 'A line about what you saw'),
        const EmInfoBanner(key: Key('ey_quick_private'), tone: EmTone.neutral, text: 'Quick observations are private: only staff can see them.'),
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
          child: Obx(() => EmPrimaryButton(key: const Key('ey_quick_submit'), loading: c.saving.value, label: 'Save observation', onPressed: c.saving.value ? null : () => _submit(context))),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case EySaved<EceObservation>():
        ToastUtil.showToast('Observation saved');
        Get.back();
      case EyInvalid<EceObservation>():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(r.errors.values.first), margin: EmSpacing.snackAboveBar));
      case EyFailed<EceObservation>(:final failure):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message), margin: EmSpacing.snackAboveBar));
      case EyIgnored<EceObservation>():
        break;
    }
  }
}
