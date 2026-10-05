import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../../../components/custom_text_field.dart';
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
        Obx(() => CustomTextField(
              controller: _paste,
              hintText: 'Paste reset code or link',
              keyboardType: TextInputType.url,
              errorText: c.pasteError.value,
              onChanged: (_) => c.pasteError.value = null,
            )),
        const SizedBox(height: AppSpacing.sm),
        const CustomText(
            text: 'Opening the link from your email on this phone fills this in automatically. '
                'You can also paste the whole link or just the code.',
            color: AppColors.faint,
            fontSize: 11),
        const SizedBox(height: AppSpacing.lg),
        CustomButton(
          label: 'Continue',
          color: AppColors.primaryColor,
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
          Obx(() => CustomTextField(
                controller: _password,
                hintText: 'New password',
                obscureText: c.obscure.value,
                validator: Validators.newPassword,
                suffixIcon: PasswordVisibilityButton(obscured: c.obscure.value, onToggle: c.obscure.toggle),
              )),
          const SizedBox(height: AppSpacing.md),
          Obx(() => CustomTextField(
                controller: _confirm,
                hintText: 'Confirm new password',
                obscureText: c.obscure.value,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onFieldSubmitted: (_) => _submit(),
              )),
          Obx(() => c.error.value == null
              ? const SizedBox(height: AppSpacing.lg)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: AuthBanner(message: c.error.value!),
                )),
          Obx(() => CustomButton(
                label: c.submitting.value ? 'Updating...' : 'Update password',
                enabled: !c.submitting.value,
                onPressed: _submit,
                color: AppColors.primaryColor,
              )),
          const SizedBox(height: AppSpacing.sm),
          Obx(() => c.tokenRejected.value
              ? TextButton(
                  onPressed: c.requestNewLink,
                  child: const CustomText(text: 'Request a new reset link', color: AppColors.blue, fontSize: 12),
                )
              : TextButton(
                  onPressed: () {
                    _paste.clear();
                    c.clearToken();
                  },
                  child: const CustomText(text: 'Use a different code or link', color: AppColors.blue, fontSize: 12),
                )),
        ],
      ),
    );
  }
}
