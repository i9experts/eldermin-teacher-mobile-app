import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../controllers/ey_submit.dart';
import '../controllers/portfolio_form_controller.dart';
import 'widgets/early_years_widgets.dart';
import 'widgets/ey_form_widgets.dart';

/// New portfolio entry (`/early-years/child/:id/portfolio/new`): PRIVATE unless the share switch is turned on and confirmed.
class PortfolioFormScreen extends GetView<PortfolioFormController> {
  const PortfolioFormScreen({super.key});

  PortfolioFormController get c => controller;

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
        appBar: EmAppBar(title: 'New portfolio entry'),
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
    return ListView(
      padding: EmSpacing.listPadding,
      children: [
        if (failure != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EmInfoBanner(key: const Key('ey_submit_error'), tone: EmTone.error, text: failure.message)),
        if (k != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.block), child: EceChildTile(child: k)),
        eyField(label: 'Title *', controller: c.titleC, fieldKey: const Key('ey_pf_title'), hint: 'e.g. Mixing colours', error: errors['title'], onChanged: (_) => c.errors.remove('title')),
        eyField(label: 'What happened *', controller: c.narrativeC, fieldKey: const Key('ey_pf_narrative'), maxLines: 5, hint: 'Describe the activity and the learning', error: errors['narrative'], onChanged: (_) => c.errors.remove('narrative')),
        eyField(label: 'Try this at home', controller: c.tryHomeC, fieldKey: const Key('ey_pf_tryhome'), maxLines: 3, hint: 'A simple idea the family can try (optional)'),
        EyPhotosSection(photos: c.photos, error: errors['photos']),
        Obx(() => EyShareSwitch(value: c.share.value, onChanged: c.setShare, note: c.share.value ? "The guardian will be emailed, and parents will see this entry in their app." : 'Off: only staff can see it.')),
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
          child: Obx(() => EmPrimaryButton(key: const Key('ey_pf_submit'), loading: c.saving.value, label: 'Save entry', onPressed: c.saving.value ? null : () => _submit(context))),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final problems = c.validate();
    if (problems.isEmpty && c.needsShareConfirm) {
      final ok = await ConfirmDialog.show(title: PortfolioFormController.shareConfirmTitle, message: PortfolioFormController.shareConfirmMessage, confirmLabel: 'Share and save', cancelLabel: 'Go back');
      if (!ok) return;
    }
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case EySaved<EcePortfolioEntry>():
        ToastUtil.showToast('Entry saved');
        Get.back();
      case EyInvalid<EcePortfolioEntry>():
        _snack(context, r.errors.values.first);
      case EyFailed<EcePortfolioEntry>(:final failure):
        _snack(context, failure.message);
      case EyIgnored<EcePortfolioEntry>():
        break;
    }
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), margin: EmSpacing.snackAboveBar));
}
