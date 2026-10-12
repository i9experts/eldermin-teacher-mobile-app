import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../components/custom_button.dart';

/// Shown instead of a route the signed-in user may not open (see RouteGuard). Deliberately generic: no module or permission names.
class NotAvailableScreen extends StatelessWidget {
  const NotAvailableScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(children: [
            const Expanded(
              child: AppEmptyView(
                icon: Icons.lock_outline_rounded,
                title: 'Not available for your account',
                subtitle: 'This page is not part of what your account can use. If you think this is a mistake, contact your school administration.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: CustomButton(
                label: 'Back to home',
                color: AppColors.primaryColor,
                width: double.infinity,
                onPressed: () => Get.until((route) => route.isFirst),
              ),
            ),
          ]),
        ),
      );
}
