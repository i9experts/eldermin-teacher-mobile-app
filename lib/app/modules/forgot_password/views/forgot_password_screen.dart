import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/validators.dart';
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
              EmTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline_rounded,
                fillColor: EmColors.background,
                radius: EmRadius.pill,
                validator: Validators.email,
                onSubmitted: (_) => _submit(),
              ),
              Obx(() => c.error.value == null
                  ? const SizedBox(height: EmSpacing.s20)
                  : Padding(
                      padding: const EdgeInsetsDirectional.symmetric(vertical: EmSpacing.s12),
                      child: AuthBanner(message: c.error.value!),
                    )),
              Obx(() => EmPrimaryButton(
                    label: c.submitting.value ? 'Sending...' : 'Send reset link',
                    loading: c.submitting.value,
                    onPressed: _submit,
                  )),
              const SizedBox(height: EmSpacing.s4),
              TextButton(
                onPressed: () => Get.toNamed(Routes.resetPassword),
                child: const Text('I already have a reset code'),
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
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: EmColors.successContainer, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, size: 34, color: EmColors.onSuccessContainer),
            ),
          ),
          const SizedBox(height: EmSpacing.s16),
          Text('Open the link on this phone, or copy the link and paste it on the next screen.',
              textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
          const SizedBox(height: EmSpacing.s20),
          EmPrimaryButton(
            label: 'I have a reset code or link',
            onPressed: () => Get.toNamed(Routes.resetPassword),
          ),
          const SizedBox(height: EmSpacing.s4),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}
