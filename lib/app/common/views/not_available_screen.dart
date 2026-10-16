import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/design/design.dart';

/// Shown instead of a route the signed-in user may not open (see RouteGuard). Deliberately generic: no module or permission names.
class NotAvailableScreen extends StatelessWidget {
  const NotAvailableScreen({super.key});

  @override
  Widget build(BuildContext context) => EmScaffold(
        extendBody: false,
        body: SafeArea(
          child: Column(children: [
            const Expanded(
              child: EmEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Not available for your account',
                message: 'This page is not part of what your account can use. If you think this is a mistake, contact your school administration.',
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(EmSpacing.screenH),
              child: EmPrimaryButton(
                label: 'Back to home',
                onPressed: () => Get.until((route) => route.isFirst),
              ),
            ),
          ]),
        ),
      );
}
