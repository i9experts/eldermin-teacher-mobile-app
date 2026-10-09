import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/account_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/action_failure.dart';
import '../../../components/custom_text.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/delete_account_controller.dart';

/// Delete-account request (`/delete-account`).
class DeleteAccountScreen extends GetView<DeleteAccountController> {
  const DeleteAccountScreen({super.key});
  DeleteAccountController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          key: const Key('delete_explainer'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(text: 'This is a request, not an instant deletion', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.amberText),
            SizedBox(height: 6),
            CustomText(text: "Sending this asks your school administration to delete your Eldermin Teacher account. They process it themselves. Until they do, your account stays active and you can keep using the app, and your records are retained. We won't sign you out.", fontSize: 12.5, color: AppColors.amberText, height: 1.45),
          ]),
        ),
        const SizedBox(height: 16),
        if (f != null) ErrorBanner(bannerKey: const Key('delete_error'), message: _failureText(f)),
        LabeledField(label: 'Reason (optional)', controller: c.reasonC, fieldKey: const Key('delete_reason'), maxLines: 3, maxLength: kDeleteReasonMax, hint: 'Tell the school why, if you want to'),
        const FormLabel('To confirm, type DELETE'),
        TextField(
          key: const Key('delete_confirm_field'),
          controller: c.confirmC,
          onChanged: c.onConfirmChanged,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(isDense: true, hintText: 'DELETE', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line))),
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  key: const Key('delete_submit'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.redText),
                  onPressed: c.canSubmit ? c.submit : null,
                  child: c.sending.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'Request account deletion', color: Colors.white, fontWeight: FontWeight.w700),
                )),
          ),
        ),
      );

  Widget _done(DeletionRequestResult r) {
    final already = r.alreadyRequested;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: already ? AppColors.amberBg : AppColors.greenBg, shape: BoxShape.circle), child: Icon(already ? Icons.hourglass_top_rounded : Icons.check_rounded, size: 38, color: already ? AppColors.amberText : AppColors.greenText)),
        const SizedBox(height: 16),
        CustomText(key: const Key('delete_done_title'), text: already ? 'You already have a pending request' : 'Request sent', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        CustomText(key: const Key('delete_done_status'), text: 'Status: ${_status(r.status)}', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
        const SizedBox(height: 10),
        CustomText(
          key: const Key('delete_done_message'),
          text: r.message ?? 'The school administration will process it. Your account stays active until then, and your records are retained.',
          fontSize: 13,
          color: AppColors.muted,
          height: 1.45,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(key: const Key('delete_done'), onPressed: () => Get.back(), child: const CustomText(text: 'Done', color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  String _status(String s) => s.isEmpty ? 'Pending' : s[0].toUpperCase() + s.substring(1);
}
