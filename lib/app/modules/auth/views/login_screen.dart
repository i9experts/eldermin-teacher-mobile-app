import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/validators.dart';
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
                padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.s16),
                child: AuthBanner(message: notice),
              );
            }),
            EmTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              prefixIcon: Icons.mail_outline_rounded,
              fillColor: EmColors.background,
              radius: EmRadius.pill,
              validator: Validators.email,
            ),
            const SizedBox(height: EmSpacing.s12),
            Obx(() => EmTextField(
                  controller: _password,
                  label: 'Password',
                  obscureText: c.obscure.value,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  prefixIcon: Icons.lock_outline_rounded,
                  fillColor: EmColors.background,
                  radius: EmRadius.pill,
                  validator: Validators.requiredPassword,
                  onSubmitted: (_) => _submit(),
                  suffix: PasswordVisibilityButton(
                    obscured: c.obscure.value,
                    onToggle: c.obscure.toggle,
                  ),
                )),
            const SizedBox(height: EmSpacing.s4),
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InkWell(
                        key: const Key('school_code_toggle'),
                        onTap: c.schoolExpanded.toggle,
                        borderRadius: EmRadius.smAll,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(
                              child: Text('Signing in to a specific school?',
                                  style: EmType.label.copyWith(color: EmColors.onPrimaryDark)),
                            ),
                            Icon(c.schoolExpanded.value ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: EmColors.onPrimaryDark, size: 20),
                          ]),
                        ),
                      ),
                    ),
                    if (c.schoolExpanded.value) ...[
                      EmTextField(
                        controller: _schoolCode,
                        label: 'School code',
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.school_outlined,
                        fillColor: EmColors.background,
                        radius: EmRadius.pill,
                        helper: 'Only needed if your email is used at more than one school.',
                      ),
                    ],
                  ],
                )),
            Obx(() => c.error.value == null
                ? const SizedBox(height: EmSpacing.s16)
                : Padding(
                    padding: const EdgeInsetsDirectional.symmetric(vertical: EmSpacing.s12),
                    child: AuthBanner(message: c.error.value!),
                  )),
            Obx(() => EmPrimaryButton(
                  label: c.loading.value ? 'Signing in...' : 'Sign in',
                  loading: c.loading.value,
                  onPressed: _submit,
                )),
            const SizedBox(height: EmSpacing.s4),
            TextButton(
              onPressed: () => Get.toNamed(Routes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}
