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
    // one shell for both states: its entrance does not replay, the hero just gains the glyph and the card swaps its content
    return Obx(() {
      final sent = c.sent.value;
      return AuthPageShell(
        showBack: true,
        title: sent ? 'Check your email' : 'Forgot password?',
        subtitle: sent ? ForgotPasswordController.genericMessage : "Enter your email and we'll send you a reset link",
        // the logo's nodes assemble into an envelope in the hero
        glyph: sent ? const EmAssembleGlyph(kind: EmGlyphKind.envelope, semanticLabel: 'Email sent') : null,
        child: AnimatedSwitcher(
          duration: EmMotion.crossfade,
          child: sent ? const _SentBody(key: ValueKey('sent')) : _form(),
        ),
      );
    });
  }

  Widget _form() {
    return KeyedSubtree(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmStagger(
                index: 0,
                child: EmTextField(
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
                )),
            Obx(() => c.error.value == null
                ? const SizedBox(height: EmSpacing.s20)
                : Padding(
                    padding: const EdgeInsetsDirectional.symmetric(vertical: EmSpacing.s12),
                    child: AuthBanner(message: c.error.value!),
                  )),
            EmStagger(
              index: 1,
              child: Obx(() => EmPrimaryButton(
                    label: c.submitting.value ? 'Sending...' : 'Send reset link',
                    loading: c.submitting.value,
                    onPressed: _submit,
                  )),
            ),
            const SizedBox(height: EmSpacing.s4),
            EmStagger(
              index: 2,
              child: TextButton(
                onPressed: () => Get.toNamed(Routes.resetPassword),
                child: const Text('I already have a reset code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentBody extends StatelessWidget {
  const _SentBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Open the link on this phone, or copy the link and paste it on the next screen.',
            textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmOnDark.muted(context), fontWeight: FontWeight.w400)),
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
    );
  }
}
