import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../classes/views/classes_screen.dart' show TabHeading;
import '../controllers/more_controller.dart';

/// More tab: profile summary card, permission-filtered module entries (Part D), then the
/// always-available account items. Early Years has a catalog slot but is hidden in v1.
class MoreScreen extends GetView<MoreController> {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = controller.entries;
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s24),
        children: [
          const TabHeading(title: 'More', caption: 'Everything else you can do'),
          const SizedBox(height: EmSpacing.s8),
          const _ProfileCard(),
          if (entries.isNotEmpty) const SectionRow(title: 'Modules') else const SizedBox(height: EmSpacing.s8),
          for (final e in entries) _row(icon: e.icon, title: e.title, subtitle: e.subtitle, onTap: () => Get.toNamed(e.route)),
          const SectionRow(title: 'Account'),
          _row(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'Alerts and updates', onTap: () => Get.toNamed(Routes.notifications)),
          _row(icon: Icons.person_outline_rounded, title: 'Profile', subtitle: 'Your details and settings', onTap: () => Get.toNamed(Routes.profile)),
          _row(icon: Icons.help_outline_rounded, title: 'Help', subtitle: 'Guides and support', onTap: () => Get.toNamed(Routes.help)),
          _row(icon: Icons.info_outline_rounded, title: 'About', subtitle: 'App version', onTap: () => Get.toNamed(Routes.about)),
          _row(
              key: const Key('more_sign_out'),
              icon: Icons.logout_rounded,
              destructive: true,
              title: 'Sign out',
              subtitle: 'Sign out of this device',
              onTap: controller.confirmAndLogout),
        ],
      );
    });
  }

  Widget _row({Key? key, required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool destructive = false}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.row),
      child: EmListRow(
        key: key,
        leading: destructive
            ? Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: EmColors.errorContainer, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(icon, size: 22, color: EmColors.onErrorContainer)),
              )
            : null,
        icon: destructive ? null : icon,
        title: title,
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

/// Who is signed in: avatar, name, campus · department, email. Tap opens Profile. Only data the app already has.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final user = auth.user.value;
      final subtitle = auth.staffMe.value?.subtitle ?? '';
      final name = (user?.name ?? '').trim().isEmpty ? 'Teacher' : user!.name;
      return EmCard(
        key: const Key('more_profile_card'),
        elevated: true,
        onTap: () => Get.toNamed(Routes.profile),
        padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
        semanticLabel: 'Profile, $name${subtitle.isEmpty ? '' : ', $subtitle'}',
        child: Row(children: [
          EmAvatar(initials: user?.initials ?? '--', imageUrl: user?.avatarUrl, size: 56),
          const SizedBox(width: EmSpacing.s16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
              if ((user?.email ?? '').isNotEmpty)
                Text(user!.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
        ]),
      );
    });
  }
}
