import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/academic/syllabus_models.dart';
import '../../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../../core/widgets/app_widgets.dart';

/// Progress bar with "covered of total · percent" text.
class ProgressBlock extends StatelessWidget {
  final SyllabusProgress progress;
  final String? label;
  final Key? barKey;
  const ProgressBlock({super.key, required this.progress, this.label, this.barKey});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final color = p.isComplete ? EmColors.success : EmColors.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label ?? (p.total == 0 ? 'Nothing to track yet' : '${p.covered} of ${p.total} covered'), style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600))),
        if (p.total > 0) Text('${p.percent}%', style: EmType.valueSmall.copyWith(color: EmColors.ink)),
      ]),
      const SizedBox(height: EmSpacing.s8),
      KeyedSubtree(key: barKey, child: AppProgressBar(percent: p.percent, color: color)),
    ]);
  }
}

/// A tickable coverage box (48dp target). [busy] = a request is in flight (the tick is already shown, optimistically). Covered / not
/// covered differ by the glyph (check vs empty box), not only by colour.
class CoverageBox extends StatelessWidget {
  final bool covered;
  final bool busy;
  final bool enabled;
  final VoidCallback? onTap;
  const CoverageBox({super.key, required this.covered, this.busy = false, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final glyph = covered ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded;
    return Semantics(
      button: true,
      checked: covered,
      enabled: enabled && !busy,
      onTap: enabled && !busy ? onTap : null,
      excludeSemantics: true,
      label: covered ? 'Covered' : 'Not covered',
      child: InkResponse(
        onTap: enabled && !busy ? onTap : null,
        radius: EmSpacing.s24,
        child: SizedBox(
          width: EmSpacing.minTouch,
          height: EmSpacing.minTouch,
          child: Center(
            child: busy
                ? Stack(alignment: Alignment.center, children: [
                    Icon(glyph, size: 24, color: EmColors.textSecondary),
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 1.5, color: EmColors.primary)),
                  ])
                : Icon(glyph, size: 24, color: covered ? EmColors.success : (enabled ? EmColors.textSecondary : EmColors.onDisabled)),
          ),
        ),
      ),
    );
  }
}

/// A list tile of a syllabus.
class SyllabusTile extends StatelessWidget {
  final Syllabus syllabus;
  final bool assignedToMe;
  final VoidCallback onTap;
  const SyllabusTile({super.key, required this.syllabus, required this.assignedToMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = syllabus;
    final sub = [if (s.term.isNotEmpty) s.term, if (s.academicYearLabel.isNotEmpty) s.academicYearLabel].join(' · ');
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    return AppCard(
      key: ValueKey('syl_${s.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(s.subjectName.isEmpty ? '(No subject)' : s.subjectName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          Wrap(spacing: EmSpacing.s4, runSpacing: EmSpacing.s4, children: [
            if (s.isBehind) const AppTag('BEHIND SCHEDULE', style: TagStyle.red),
            if (s.trackStatus == 'completed' || s.progress.isComplete) const AppTag('COMPLETED', style: TagStyle.green),
            if (s.status == 'draft') const AppTag('DRAFT', style: TagStyle.neutral),
          ]),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text([s.classLabel, sub].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
        const SizedBox(height: EmSpacing.row),
        ProgressBlock(progress: s.progress, barKey: ValueKey('syl_bar_${s.id}')),
        const SizedBox(height: EmSpacing.s8),
        Row(children: [
          ExcludeSemantics(child: Icon(assignedToMe ? Icons.person_outline_rounded : Icons.groups_outlined, size: 16, color: EmColors.textSecondary)),
          const SizedBox(width: EmSpacing.s4),
          Text(assignedToMe ? 'Assigned to you' : 'Your class', style: quiet.copyWith(fontWeight: FontWeight.w600)),
          if (!assignedToMe && s.teacherName.isNotEmpty) Flexible(child: Text(' · ${s.teacherName}', style: quiet)),
        ]),
      ]),
    );
  }
}
