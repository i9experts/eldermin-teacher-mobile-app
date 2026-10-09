import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/about_controller.dart';

/// About (`/about`).
class AboutScreen extends GetView<AboutController> {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 24), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: CustomText(key: Key('about_name'), text: 'Eldermin Teacher', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
        const Center(child: Padding(padding: EdgeInsets.only(top: 4), child: CustomText(text: 'Classroom, attendance and communication tools for school staff.', fontSize: 12, color: AppColors.muted, textAlign: TextAlign.center))),
        const SizedBox(height: 20),
        Obx(() {
          final i = c.info.value;
          return AppCard(
            child: Column(children: [
              _row('Version', i == null ? (c.failed.value ? 'Unavailable' : '...') : i.version, const Key('about_version')),
              _row('Build', i == null ? (c.failed.value ? 'Unavailable' : '...') : i.build, const Key('about_build')),
              _row('Server', AboutController.apiHost.isEmpty ? 'Unavailable' : AboutController.apiHost, const Key('about_host')),
            ]),
          );
        }),
        ListCardRow(key: const Key('about_help'), icon: Icons.help_outline_rounded, title: 'Help', subtitle: 'Guides and support', trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint), onTap: () => Get.toNamed(Routes.help)),
      ]),
    );
  }

  Widget _row(String k, String v, Key key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 90, child: CustomText(text: k, fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
          Expanded(child: CustomText(key: key, text: v, fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
        ]),
      );
}
