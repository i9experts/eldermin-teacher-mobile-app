import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/app_widgets.dart' show AppCard, ListCardRow;
import '../../../routes/app_routes.dart';
import '../controllers/about_controller.dart';
import '../../../../core/design/design.dart';

/// About (`/about`).
class AboutScreen extends GetView<AboutController> {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return EmScaffold(
      appBar: EmAppBar(title: 'About'),
      body: ListView(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s24, EmSpacing.screenH, EmSpacing.s24), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: EmColors.primary, borderRadius: EmRadius.tileAll),
            child: const Icon(Icons.school_rounded, color: EmColors.onPrimary, size: 36),
          ),
        ),
        const SizedBox(height: EmSpacing.s12),
        Center(child: Text('Eldermin Teacher', key: const Key('about_name'), style: EmType.title.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
        Center(child: Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text('Classroom, attendance and communication tools for school staff.', textAlign: TextAlign.center, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)))),
        const SizedBox(height: EmSpacing.s20),
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
        ListCardRow(key: const Key('about_help'), icon: Icons.help_outline_rounded, title: 'Help', subtitle: 'Guides and support', trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textTertiary), onTap: () => Get.toNamed(Routes.help)),
      ]),
    );
  }

  Widget _row(String k, String v, Key key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: EmSpacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text(k, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, key: key, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
        ]),
      );
}
