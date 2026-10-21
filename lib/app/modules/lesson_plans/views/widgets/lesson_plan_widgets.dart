import 'package:flutter/material.dart';
import '../../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';

/// Status chip of a plan (colour + words, never colour alone).
class PlanStatusTag extends StatelessWidget {
  final LessonPlanStatus status;
  const PlanStatusTag(this.status, {super.key});

  @override
  Widget build(BuildContext context) => switch (status) {
        LessonPlanStatus.draft => const AppTag('DRAFT', style: EmTone.neutral),
        LessonPlanStatus.submitted => const AppTag('AWAITING APPROVAL', style: EmTone.info),
        LessonPlanStatus.approved => const AppTag('APPROVED', style: EmTone.success),
        LessonPlanStatus.rejected => const AppTag('REJECTED', style: EmTone.error),
        LessonPlanStatus.overdue => const AppTag('OVERDUE', style: EmTone.warning),
        LessonPlanStatus.unknown => const AppTag('UNKNOWN', style: EmTone.neutral),
      };
}

class LessonPlanTile extends StatelessWidget {
  final LessonPlanRecord plan;
  final VoidCallback onTap;
  const LessonPlanTile({super.key, required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final day = p.planDay;
    final reason = p.rejectionReason;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    return AppCard(
      key: ValueKey('lp_${p.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(p.topic.isEmpty ? '(No topic)' : p.topic, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          PlanStatusTag(p.status),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text([p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
        const SizedBox(height: EmSpacing.s8),
        Wrap(spacing: EmSpacing.s16, runSpacing: EmSpacing.s4, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const ExcludeSemantics(child: Icon(Icons.event_rounded, size: 16, color: EmColors.textSecondary)),
            const SizedBox(width: EmSpacing.s4),
            Text(day == null ? 'No date' : shortDay(day), style: quiet.copyWith(fontWeight: FontWeight.w600)),
          ]),
          if (p.durationMins != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const ExcludeSemantics(child: Icon(Icons.schedule_rounded, size: 16, color: EmColors.textSecondary)),
              const SizedBox(width: EmSpacing.s4),
              Text('${p.durationMins} min', style: quiet.copyWith(fontWeight: FontWeight.w600)),
            ]),
        ]),
        if (p.status == LessonPlanStatus.rejected) ...[
          const SizedBox(height: EmSpacing.s8),
          Container(
            key: ValueKey('lp_reason_${p.id}'),
            width: double.infinity,
            padding: EmSpacing.cardPadCompact,
            decoration: BoxDecoration(color: EmColors.errorContainer, borderRadius: EmRadius.smAll),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ExcludeSemantics(child: Icon(Icons.cancel_outlined, size: 16, color: EmColors.onErrorContainer)),
              const SizedBox(width: EmSpacing.s8),
              Expanded(child: Text(reason == null || reason.isEmpty ? 'Rejected (no reason given)' : 'Rejected: $reason', maxLines: 3, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.onErrorContainer, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// A tone note (decision / hint / warning) with an icon, a bold title and an optional body.
class NoteBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final EmTone tone;
  final Key? boxKey;
  const NoteBox({super.key, this.boxKey, required this.icon, required this.title, this.body, this.tone = EmTone.info});

  @override
  Widget build(BuildContext context) => Padding(
        key: boxKey,
        padding: const EdgeInsets.only(bottom: EmSpacing.row),
        child: Semantics(
          container: true,
          liveRegion: tone == EmTone.error,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tone.background, borderRadius: EmRadius.mdAll),
            child: Padding(
              padding: EmSpacing.cardPadCompact,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(child: Icon(icon, size: 20, color: tone.foreground)),
                const SizedBox(width: EmSpacing.s8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: EmType.label.copyWith(color: tone.foreground)),
                    if (body != null && body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(body!, style: EmType.body.copyWith(color: tone.foreground, fontWeight: FontWeight.w400, height: 1.4))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
