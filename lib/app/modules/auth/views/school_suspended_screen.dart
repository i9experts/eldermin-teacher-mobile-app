import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../controllers/auth_controller.dart';

/// Shown instead of the app when the server answers 403 SCHOOL_SUSPENDED: the server's own message and a single way out, "Log out".
class SchoolSuspendedScreen extends StatelessWidget {
  const SchoolSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(() => EmEmptyState(
                    key: const Key('school_suspended'),
                    icon: Icons.lock_outline_rounded,
                    title: "Your school's account is suspended",
                    message: auth.schoolSuspendedMessage.value ?? '',
                  )),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(EmSpacing.screenH),
              child: EmPrimaryButton(key: const Key('school_suspended_logout'), label: 'Log out', onPressed: auth.logout),
            ),
          ],
        ),
      ),
    );
  }
}
