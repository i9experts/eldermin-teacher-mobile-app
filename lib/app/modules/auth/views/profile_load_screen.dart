import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
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
    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        child: Obx(() {
          final error = auth.profileError.value;
          if (error == null) return const EmLoading();
          return Column(
            children: [
              Expanded(child: EmErrorState(message: error, onRetry: auth.retryRestore, retryLabel: 'Try again')),
              TextButton(
                onPressed: auth.logout,
                child: const Text('Sign out'),
              ),
              const SizedBox(height: EmSpacing.s20),
            ],
          );
        }),
      ),
    );
  }
}
