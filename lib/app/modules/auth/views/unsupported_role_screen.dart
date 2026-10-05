import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../controllers/auth_controller.dart';

/// Shown when the signed-in role is not in the app's allow-list. Shell
/// only (Phase 3 polishes the copy) - but the sign-out is real.
class UnsupportedRoleScreen extends StatelessWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: AppEmptyView(
                icon: Icons.desktop_windows_rounded,
                title: 'Please use the Eldermin web portal',
                subtitle: 'This app is for teachers. Your account role is not supported here yet.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Obx(() => CustomText(
                      text: auth.user.value?.email ?? '',
                      color: AppColors.muted,
                      fontSize: 12)),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton(
                    label: 'Sign out',
                    color: AppColors.primaryColor,
                    width: double.infinity,
                    onPressed: auth.logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
