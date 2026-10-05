import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/common_image_view.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../../../components/custom_text_field.dart';
import '../../../config/app_images.dart';
import '../../../routes/app_routes.dart';
import '../bindings/login_binding.dart';
import '../controllers/login_controller.dart';

/// Minimal sign-in shell (email + password + optional school code). The
/// polished Phase 3 flow replaces the layout; the plumbing is real.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController c;

  @override
  void initState() {
    super.initState();
    LoginBinding().dependencies();
    c = Get.find<LoginController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: 84,
                    child: CommonImageView(imagePath: AppImages.fullLogo, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const CustomText(
                      text: 'Eldermin Teacher',
                      textAlign: TextAlign.center,
                      color: AppColors.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                  const SizedBox(height: 4),
                  const CustomText(
                      text: 'Sign in with your school account',
                      textAlign: TextAlign.center,
                      color: AppColors.muted,
                      fontSize: 13),
                  const SizedBox(height: AppSpacing.xl),
                  CustomTextField(
                      controller: c.email,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => CustomTextField(
                        controller: c.password,
                        hintText: 'Password',
                        obscureText: c.obscure.value,
                        suffixIcon: IconButton(
                          icon: Icon(c.obscure.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20),
                          onPressed: () => c.obscure.toggle(),
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                  CustomTextField(controller: c.schoolCode, hintText: 'School code (optional)'),
                  Obx(() => c.error.value == null
                      ? const SizedBox(height: AppSpacing.md)
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: CustomText(text: c.error.value!, color: AppColors.red, fontSize: 12),
                        )),
                  Obx(() => CustomButton(
                        label: c.loading.value ? 'Signing in...' : 'Sign in',
                        enabled: !c.loading.value,
                        onPressed: c.submit,
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
          ),
        ),
      ),
    );
  }
}
