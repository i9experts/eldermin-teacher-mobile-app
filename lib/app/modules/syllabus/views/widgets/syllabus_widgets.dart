import 'package:flutter/material.dart';
import '../../../../../core/models/academic/syllabus_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';

/// Progress bar with "covered of total · percent" text.
class ProgressBlock extends StatelessWidget {
  final SyllabusProgress progress;
  final String? label;
  final Key? barKey;
  const ProgressBlock({super.key, required this.progress, this.label, this.barKey});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final color = p.isComplete ? AppColors.secondryColor : AppColors.blue;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: CustomText(text: label ?? (p.total == 0 ? 'Nothing to track yet' : '${p.covered} of ${p.total} covered'), color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
        if (p.total > 0) CustomText(text: '${p.percent}%', color: AppColors.primaryColor, fontSize: 12, fontWeight: FontWeight.w800),
      ]),
      const SizedBox(height: 5),
      KeyedSubtree(key: barKey, child: AppProgressBar(percent: p.percent, color: color)),
    ]);
  }
}

/// A tickable coverage box. [busy] = a request is in flight (the tick is already shown, optimistically).
class CoverageBox extends StatelessWidget {
  final bool covered;
  final bool busy;
  final bool enabled;
  final VoidCallback? onTap;
  const CoverageBox({super.key, required this.covered, this.busy = false, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled && !busy ? onTap : null,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: busy
            ? SizedBox(width: 22, height: 22, child: Stack(alignment: Alignment.center, children: [
                Icon(covered ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 22, color: AppColors.muted),
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryColor)),
              ]))
            : Icon(covered ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 22, color: covered ? AppColors.secondryColor : AppColors.lightGrey5),
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
    return AppCard(
      key: ValueKey('syl_${s.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: CustomText(text: s.subjectName.isEmpty ? '(No subject)' : s.subjectName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Wrap(spacing: 4, children: [
            if (s.isBehind) const AppTag('BEHIND SCHEDULE', style: TagStyle.red),
            if (s.trackStatus == 'completed' || s.progress.isComplete) const AppTag('COMPLETED', style: TagStyle.green),
            if (s.status == 'draft') const AppTag('DRAFT', style: TagStyle.neutral),
          ]),
        ]),
        const SizedBox(height: 3),
        CustomText(text: [s.classLabel, sub].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 11),
        const SizedBox(height: 10),
        ProgressBlock(progress: s.progress, barKey: ValueKey('syl_bar_${s.id}')),
        const SizedBox(height: 8),
        Row(children: [
          Icon(assignedToMe ? Icons.person_outline_rounded : Icons.groups_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          CustomText(text: assignedToMe ? 'Assigned to you' : 'Your class', color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700),
          if (!assignedToMe && s.teacherName.isNotEmpty) CustomText(text: ' · ${s.teacherName}', color: AppColors.muted, fontSize: 10.5),
        ]),
      ]),
    );
  }
}
