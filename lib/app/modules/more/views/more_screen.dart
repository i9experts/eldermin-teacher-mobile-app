import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/module_tile.dart';
import '../../../routes/app_routes.dart';
import '../controllers/more_controller.dart';

/// More tab: permission-filtered module entries (Part D), then the
/// always-available account items. Early Years has a catalog slot but is
/// hidden in v1.
class MoreScreen extends GetView<MoreController> {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = controller.entries;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ScreenHeader(title: 'More', caption: 'Everything else you can do'),
          for (final e in entries)
            ModuleTile(icon: e.icon, title: e.title, subtitle: e.subtitle, onTap: () => Get.toNamed(e.route)),
          const SizedBox(height: 8),
          const SectionRow(title: 'Account'),
          ModuleTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Alerts and updates',
              onTap: () => Get.toNamed(Routes.notifications)),
          ModuleTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Your details and settings',
              onTap: () => Get.toNamed(Routes.profile)),
          ModuleTile(
              icon: Icons.help_outline_rounded,
              title: 'Help',
              subtitle: 'Guides and support',
              onTap: () => Get.toNamed(Routes.help)),
          ModuleTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'App version',
              onTap: () => Get.toNamed(Routes.about)),
          ModuleTile(
              icon: Icons.logout_rounded,
              iconColor: Colors.red.shade700,
              title: 'Sign out',
              subtitle: 'Sign out of this device',
              onTap: controller.logout),
        ],
      );
    });
  }
}
