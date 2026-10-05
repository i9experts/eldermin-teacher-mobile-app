import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_text.dart';
import '../controllers/auth_controller.dart';

/// Shown while a stored session is being re-checked (`GET /auth/me` then
/// `GET /staff-portal/me`), or when that failed - e.g. offline at launch -
/// with Retry / Sign out. A network failure is never a logout. The home shell is never
/// built without a resolved profile, so staffId is always available to it.
class ProfileLoadScreen extends StatelessWidget {
  const ProfileLoadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final error = auth.profileError.value;
          if (error == null) return const AppLoader();
          return Column(
            children: [
              Expanded(child: AppErrorView(message: error, onRetry: auth.retryRestore)),
              TextButton(
                onPressed: auth.logout,
                child: const CustomText(text: 'Sign out', color: AppColors.blue, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        }),
      ),
    );
  }
}
