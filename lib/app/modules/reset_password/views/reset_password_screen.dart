import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/validators.dart';
import '../../auth/views/auth_widgets.dart';
import '../bindings/reset_password_binding.dart';
import '../controllers/reset_password_controller.dart';

/// Set a new password (`/reset-password`). Token from a deep link, or the
/// "Paste reset code or link" fallback.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final ResetPasswordController c;
  final _formKey = GlobalKey<FormState>();
  final _paste = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    ResetPasswordBinding().dependencies();
    c = Get.find<ResetPasswordController>();
  }

  @override
  void dispose() {
    _paste.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    await c.submit(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasToken = c.token.value != null;
      return AuthPageShell(
        showBack: true,
        title: 'Set a new password',
        subtitle: hasToken ? 'Choose a new password for your account' : 'Paste the code or link from your email',
        child: hasToken ? _passwordForm() : _pasteForm(),
      );
    });
  }

  Widget _pasteForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() => EmTextField(
              controller: _paste,
              label: 'Paste reset code or link',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.link_rounded,
              fillColor: EmColors.background,
              radius: EmRadius.pill,
              errorText: c.pasteError.value,
              onChanged: (_) => c.pasteError.value = null,
              onSubmitted: (_) => c.applyPasted(_paste.text),
            )),
        const SizedBox(height: EmSpacing.s8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s4),
          child: Text(
              'Opening the link from your email on this phone fills this in automatically. '
              'You can also paste the whole link or just the code.',
              style: EmType.caption.copyWith(color: EmOnDark.muted(context))),
        ),
        const SizedBox(height: EmSpacing.s20),
        EmPrimaryButton(
          label: 'Continue',
          onPressed: () => c.applyPasted(_paste.text),
        ),
      ],
    );
  }

  Widget _passwordForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => EmTextField(
                controller: _password,
                label: 'New password',
                obscureText: c.obscure.value,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                prefixIcon: Icons.lock_outline_rounded,
                fillColor: EmColors.background,
                radius: EmRadius.pill,
                validator: Validators.newPassword,
                suffix: PasswordVisibilityButton(obscured: c.obscure.value, onToggle: c.obscure.toggle),
              )),
          const SizedBox(height: EmSpacing.s12),
          Obx(() => EmTextField(
                controller: _confirm,
                label: 'Confirm new password',
                obscureText: c.obscure.value,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                prefixIcon: Icons.lock_outline_rounded,
                fillColor: EmColors.background,
                radius: EmRadius.pill,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
              )),
          Obx(() => c.error.value == null
              ? const SizedBox(height: EmSpacing.s20)
              : Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: EmSpacing.s12),
                  child: AuthBanner(message: c.error.value!),
                )),
          Obx(() => EmPrimaryButton(
                label: c.submitting.value ? 'Updating...' : 'Update password',
                loading: c.submitting.value,
                onPressed: _submit,
              )),
          const SizedBox(height: EmSpacing.s4),
          Obx(() => c.tokenRejected.value
              ? TextButton(
                  onPressed: c.requestNewLink,
                  child: const Text('Request a new reset link'),
                )
              : TextButton(
                  onPressed: () {
                    _paste.clear();
                    c.clearToken();
                  },
                  child: const Text('Use a different code or link'),
                )),
        ],
      ),
    );
  }
}
