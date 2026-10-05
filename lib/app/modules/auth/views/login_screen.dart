import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../../../components/custom_text_field.dart';
import '../../../routes/app_routes.dart';
import '../bindings/login_binding.dart';
import '../controllers/login_controller.dart';
import 'auth_widgets.dart';

/// Email + password sign-in with an optional, collapsible school code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController c;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _schoolCode = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    LoginBinding().dependencies();
    c = Get.find<LoginController>();
    c.savedSlug().then((slug) {
      if (slug != null && mounted && _schoolCode.text.isEmpty) _schoolCode.text = slug;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _schoolCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    await c.submit(email: _email.text, password: _password.text, schoolCode: _schoolCode.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      title: 'Eldermin Teacher',
      subtitle: 'Sign in with your school account',
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final notice = c.auth.loginNotice.value;
              if (notice == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AuthBanner(message: notice),
              );
            }),
            CustomTextField(
              controller: _email,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(() => CustomTextField(
                  controller: _password,
                  hintText: 'Password',
                  obscureText: c.obscure.value,
                  validator: Validators.requiredPassword,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: PasswordVisibilityButton(
                    obscured: c.obscure.value,
                    onToggle: c.obscure.toggle,
                  ),
                )),
            const SizedBox(height: AppSpacing.sm),
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        key: const Key('school_code_toggle'),
                        onTap: c.schoolExpanded.toggle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const CustomText(
                                text: 'Signing in to a specific school?',
                                color: AppColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            Icon(c.schoolExpanded.value ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: AppColors.blue, size: 18),
                          ]),
                        ),
                      ),
                    ),
                    if (c.schoolExpanded.value) ...[
                      const SizedBox(height: AppSpacing.sm),
                      CustomTextField(
                        controller: _schoolCode,
                        hintText: 'School code',
                        keyboardType: TextInputType.url,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: CustomText(
                            text: 'Only needed if your email is used at more than one school.',
                            color: AppColors.faint,
                            fontSize: 11),
                      ),
                    ],
                  ],
                )),
            Obx(() => c.error.value == null
                ? const SizedBox(height: AppSpacing.md)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: AuthBanner(message: c.error.value!),
                  )),
            Obx(() => CustomButton(
                  label: c.loading.value ? 'Signing in...' : 'Sign in',
                  enabled: !c.loading.value,
                  onPressed: _submit,
                  color: AppColors.primaryColor,
                )),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Get.toNamed(Routes.forgotPassword),
              child: const CustomText(text: 'Forgot password?', color: AppColors.blue, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
