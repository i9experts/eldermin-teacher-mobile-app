import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../../../components/custom_text_field.dart';
import '../../../routes/app_routes.dart';
import '../../auth/views/auth_widgets.dart';
import '../bindings/forgot_password_binding.dart';
import '../controllers/forgot_password_controller.dart';

/// Forgot password (`/forgot-password`): email -> generic success screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final ForgotPasswordController c;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    ForgotPasswordBinding().dependencies();
    c = Get.find<ForgotPasswordController>();
    c.reset();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    await c.submit(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.sent.value) return _Sent(email: _email.text.trim());
      return AuthPageShell(
        showBack: true,
        title: 'Forgot password?',
        subtitle: "Enter your email and we'll send you a reset link",
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _email,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
              ),
              Obx(() => c.error.value == null
                  ? const SizedBox(height: AppSpacing.lg)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: AuthBanner(message: c.error.value!),
                    )),
              Obx(() => CustomButton(
                    label: c.submitting.value ? 'Sending...' : 'Send reset link',
                    enabled: !c.submitting.value,
                    onPressed: _submit,
                    color: AppColors.primaryColor,
                  )),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Get.toNamed(Routes.resetPassword),
                child: const CustomText(text: 'I already have a reset code', color: AppColors.blue, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Sent extends StatelessWidget {
  final String email;
  const _Sent({required this.email});

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      showBack: true,
      title: 'Check your email',
      subtitle: ForgotPasswordController.genericMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.secondryColor),
          const SizedBox(height: AppSpacing.md),
          const CustomText(
              text: 'Open the link on this phone, or copy the link and paste it on the next screen.',
              textAlign: TextAlign.center,
              color: AppColors.muted,
              fontSize: 12),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(
            label: 'I have a reset code or link',
            color: AppColors.primaryColor,
            onPressed: () => Get.toNamed(Routes.resetPassword),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Get.back(),
            child: const CustomText(text: 'Back to sign in', color: AppColors.blue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
