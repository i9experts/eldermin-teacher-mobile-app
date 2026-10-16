import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../controllers/auth_controller.dart';

/// Shown when the signed-in role is not in the app's allow-list.
class UnsupportedRoleScreen extends StatelessWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: EmEmptyState(
                icon: Icons.desktop_windows_rounded,
                title: 'Please use the Eldermin web portal',
                message: 'The Eldermin Teacher app is for teaching staff. Your account is set up for a different role, '
                    'so please sign in on the Eldermin web portal instead.',
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(EmSpacing.screenH),
              child: Column(
                children: [
                  Obx(() => Text(auth.user.value?.email ?? '', textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.textSecondary))),
                  const SizedBox(height: EmSpacing.s12),
                  EmPrimaryButton(label: 'Sign out', onPressed: auth.logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
