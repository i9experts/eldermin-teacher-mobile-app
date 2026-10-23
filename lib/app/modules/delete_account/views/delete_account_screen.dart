import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/account_repository.dart';
import '../../../common/action_failure.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/delete_account_controller.dart';
import '../../../../core/design/design.dart';

/// Delete-account request (`/delete-account`).
class DeleteAccountScreen extends GetView<DeleteAccountController> {
  const DeleteAccountScreen({super.key});
  DeleteAccountController get c => controller;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Request account deletion'),
      body: Obx(() {
        final r = c.result.value;
        if (r != null) return _done(r);
        return Column(children: [Expanded(child: _form()), _bottom()]);
      }),
    );
  }

  Widget _form() {
    final f = c.failure.value;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
      children: [
        Container(
          key: const Key('delete_explainer'),
          padding: const EdgeInsets.all(EmSpacing.s16),
          decoration: BoxDecoration(color: EmTone.warning.background, borderRadius: EmRadius.mdAll),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, size: 22, color: EmTone.warning.foreground),
            const SizedBox(width: EmSpacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('This is a request, not an instant deletion', style: EmType.body.copyWith(fontWeight: FontWeight.w800, color: EmTone.warning.foreground)),
                const SizedBox(height: EmSpacing.s8),
                Text("Sending this asks your school administration to delete your Eldermin Teacher account. The school administration will process the request. Until they do, your account stays active and you can keep using the app, and your records are retained. We won't sign you out.", style: EmType.label.copyWith(fontWeight: FontWeight.w500, color: EmTone.warning.foreground, height: 1.45)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: EmSpacing.s16),
        if (f != null) ErrorBanner(bannerKey: const Key('delete_error'), message: _failureText(f)),
        LabeledField(label: 'Reason (optional)', controller: c.reasonC, fieldKey: const Key('delete_reason'), maxLines: 3, maxLength: kDeleteReasonMax, hint: 'Tell the school why, if you want to'),
        const FormLabel('To confirm this request, type DELETE'),
        TextField(
          key: const Key('delete_confirm_field'),
          controller: c.confirmC,
          onChanged: c.onConfirmChanged,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w700),
          decoration: InputDecoration(isDense: true, hintText: 'DELETE', hintStyle: EmType.body.copyWith(color: EmColors.textTertiary), filled: true, fillColor: EmColors.surface, border: OutlineInputBorder(borderRadius: EmRadius.mdAll, borderSide: const BorderSide(color: EmColors.border)), enabledBorder: OutlineInputBorder(borderRadius: EmRadius.mdAll, borderSide: const BorderSide(color: EmColors.border))),
        ),
      ],
    );
  }

  String _failureText(ActionFailure f) => switch (f.kind) {
        ActionFailureKind.forbidden => "You don't have access to request account deletion. Contact your school administration.",
        ActionFailureKind.notFound => 'Account deletion requests are not available on this server yet. Contact your school administration.',
        _ => f.message.isEmpty ? "Couldn't send this request. Nothing was sent." : f.message,
      };

  Widget _bottom() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          // destructive = the error token AND a label that says what it does (never colour alone)
          child: Obx(() => EmPrimaryButton(key: const Key('delete_submit'), label: 'Request account deletion', icon: Icons.person_remove_outlined, destructive: true, loading: c.sending.value, onPressed: c.canSubmit ? c.submit : null)),
        ),
      );

  Widget _done(DeletionRequestResult r) {
    final already = r.alreadyRequested;
    final tone = already ? EmTone.warning : EmTone.success;
    return Padding(
      padding: const EdgeInsets.all(EmSpacing.s24),
      child: SingleChildScrollView(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle), child: Icon(already ? Icons.hourglass_top_rounded : Icons.check_rounded, size: 38, color: tone.foreground)),
          const SizedBox(height: EmSpacing.s16),
          Text(already ? 'You already have a pending request' : 'Request sent', key: const Key('delete_done_title'), textAlign: TextAlign.center, style: EmType.title.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink)),
          const SizedBox(height: EmSpacing.s12),
          Text('Status: ${_status(r.status)}', key: const Key('delete_done_status'), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s12),
          Text(
            r.message ?? 'The school administration will process it. Your account stays active until then, and your records are retained.',
            key: const Key('delete_done_message'),
            textAlign: TextAlign.center,
            style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.45),
          ),
          const SizedBox(height: EmSpacing.s24),
          EmPrimaryButton(key: const Key('delete_done'), label: 'Done', onPressed: () => Get.back()),
        ]),
      ),
    );
  }

  String _status(String s) => s.isEmpty ? 'Pending' : s[0].toUpperCase() + s.substring(1);
}
