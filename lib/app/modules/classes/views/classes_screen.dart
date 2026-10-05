import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../common/module_catalog.dart';
import '../../../components/custom_text.dart';
import '../controllers/classes_controller.dart';

/// Classes tab: MY classes (from `/staff-portal/me`) and a permission-filtered grid of the classroom
/// modules. Modules that are not built yet stay in the grid, honestly labelled "Coming soon"
/// (their routes open the "still being built" page; nothing is faked).
class ClassesScreen extends GetView<ClassesController> {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuild when the session (permissions / class-teacher flag) changes.
      final entries = controller.entries;
      final classes = controller.classes;
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
          if (classes.isNotEmpty) ...[
            const SectionRow(title: 'My classes'),
            Wrap(key: const Key('my_classes'), spacing: 8, runSpacing: 8, children: [for (final c in classes) _ClassChip(cls: c)]),
            const SizedBox(height: 14),
          ],
          const SectionRow(title: 'Tools'),
          GridView.count(
            key: const Key('classes_grid'),
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [for (final e in entries) _ModuleCard(entry: e, onTap: () => Get.toNamed(e.route))],
          ),
        ],
      );
    });
  }
}

class _ClassChip extends StatelessWidget {
  final ClassRef cls;
  const _ClassChip({required this.cls});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.groups_rounded, size: 14, color: AppColors.blue),
          const SizedBox(width: 6),
          CustomText(text: cls.label, color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
          if (cls.isClassTeacherClass) const CustomText(text: ' · Class teacher', color: AppColors.muted, fontSize: 11),
        ]),
      );
}

class _ModuleCard extends StatelessWidget {
  final ModuleEntry entry;
  final VoidCallback onTap;
  const _ModuleCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('module_${entry.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(12)),
                child: Icon(entry.icon, color: entry.built ? AppColors.blue : AppColors.faint, size: 20),
              ),
              if (!entry.built) const AppTag('Coming soon', style: TagStyle.neutral),
            ]),
            const Spacer(),
            CustomText(text: entry.title, color: entry.built ? AppColors.primaryColor : AppColors.muted, fontWeight: FontWeight.w800, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
            CustomText(text: entry.subtitle, color: AppColors.faint, fontSize: 10.5, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
