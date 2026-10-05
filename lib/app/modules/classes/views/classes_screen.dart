import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/module_tile.dart';
import '../controllers/classes_controller.dart';

/// Classes tab: permission-filtered entry points into the classroom
/// modules. Each entry opens its (currently empty) module route.
class ClassesScreen extends GetView<ClassesController> {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuild when the session (permissions / class-teacher flag) changes.
      final entries = controller.entries;
      if (entries.isEmpty) {
        return const AppEmptyView(
          icon: Icons.lock_outline_rounded,
          title: 'Nothing available yet',
          subtitle: 'None of the classroom modules are enabled for your account.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ScreenHeader(title: 'Classes', caption: 'Your teaching tools'),
          for (final e in entries)
            ModuleTile(
              icon: e.icon,
              title: e.title,
              subtitle: e.subtitle,
              onTap: () => Get.toNamed(e.route),
            ),
        ],
      );
    });
  }
}
