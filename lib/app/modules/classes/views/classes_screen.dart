import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../common/module_catalog.dart';
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
        return const EmEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Nothing available yet',
          message: 'None of the classroom modules are enabled for your account.',
        );
      }
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s24),
        children: [
          const TabHeading(title: 'Classes', caption: 'Your teaching tools'),
          if (classes.isNotEmpty) ...[
            const SectionRow(title: 'My classes'),
            Wrap(key: const Key('my_classes'), spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final c in classes) _ClassChip(cls: c)]),
            const SizedBox(height: EmSpacing.s8),
          ],
          const SectionRow(title: 'Tools'),
          // Card height: 1.1 aspect ratio, but never below what the content needs at the current text scale.
          LayoutBuilder(builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
            final cardWidth = (box.maxWidth - EmSpacing.row) / 2;
            final extent = math.max(cardWidth / 1.1, 156.0 * scale);
            return GridView(
              key: const Key('classes_grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: EmSpacing.row, crossAxisSpacing: EmSpacing.row, mainAxisExtent: extent),
              children: [for (final e in entries) _ModuleCard(entry: e, onTap: () => Get.toNamed(e.route))],
            );
          }),
        ],
      );
    });
  }
}

/// Big in-body tab title + caption (the shell header above it carries the greeting).
class TabHeading extends StatelessWidget {
  final String title;
  final String? caption;
  const TabHeading({super.key, required this.title, this.caption});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(top: EmSpacing.s8, bottom: EmSpacing.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: EmType.title.copyWith(color: EmColors.ink))),
          if (caption != null) Text(caption!, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
        ]),
      );
}

class _ClassChip extends StatelessWidget {
  final ClassRef cls;
  const _ClassChip({required this.cls});

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: cls.isClassTeacherClass ? '${cls.label}, class teacher' : cls.label,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: EmTone.info.background, borderRadius: EmRadius.pillAll),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.groups_rounded, size: 16, color: EmTone.info.foreground),
              const SizedBox(width: EmSpacing.s8),
              Flexible(child: Text(cls.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmTone.info.foreground))),
              if (cls.isClassTeacherClass) Text(' · Class teacher', maxLines: 1, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ]),
          ),
        ),
      );
}

class _ModuleCard extends StatelessWidget {
  final ModuleEntry entry;
  final VoidCallback onTap;
  const _ModuleCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EmCard(
      key: ValueKey('module_${entry.id}'),
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
      semanticLabel: entry.built ? '${entry.title}, ${entry.subtitle}' : '${entry.title}, coming soon',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: EmColors.primaryTint, shape: BoxShape.circle),
            child: ExcludeSemantics(child: Icon(entry.icon, color: entry.built ? EmColors.primary : EmColors.textSecondary, size: 22)),
          ),
          const Spacer(),
          if (!entry.built) const Flexible(child: EmChip.status(label: 'Coming soon', tone: EmTone.neutral)),
        ]),
        const Spacer(),
        Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: entry.built ? EmColors.ink : EmColors.textSecondary)),
        Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
      ]),
    );
  }
}
