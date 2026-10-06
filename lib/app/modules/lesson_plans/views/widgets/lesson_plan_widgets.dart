import 'package:flutter/material.dart';
import '../../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';

/// Status chip of a plan (colour + words, never colour alone).
class PlanStatusTag extends StatelessWidget {
  final LessonPlanStatus status;
  const PlanStatusTag(this.status, {super.key});

  @override
  Widget build(BuildContext context) => switch (status) {
        LessonPlanStatus.draft => const AppTag('DRAFT', style: TagStyle.neutral),
        LessonPlanStatus.submitted => const AppTag('AWAITING APPROVAL', style: TagStyle.info),
        LessonPlanStatus.approved => const AppTag('APPROVED', style: TagStyle.green),
        LessonPlanStatus.rejected => const AppTag('REJECTED', style: TagStyle.red),
        LessonPlanStatus.overdue => const AppTag('OVERDUE', style: TagStyle.amber),
        LessonPlanStatus.unknown => const AppTag('UNKNOWN', style: TagStyle.neutral),
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
    return AppCard(
      key: ValueKey('lp_${p.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: CustomText(text: p.topic.isEmpty ? '(No topic)' : p.topic, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13.5, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          PlanStatusTag(p.status),
        ]),
        const SizedBox(height: 4),
        CustomText(text: [p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 11),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.event_rounded, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          CustomText(text: day == null ? 'No date' : shortDay(day), color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
          if (p.durationMins != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.schedule_rounded, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            CustomText(text: '${p.durationMins} min', color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
          ],
        ]),
        if (p.status == LessonPlanStatus.rejected) ...[
          const SizedBox(height: 8),
          Container(
            key: ValueKey('lp_reason_${p.id}'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: CustomText(text: reason == null || reason.isEmpty ? 'Rejected (no reason given)' : 'Rejected: $reason', color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }
}

/// A coloured note (decision / hint / warning) with an icon.
class NoteBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Color fg;
  final Color bg;
  final Key? boxKey;
  const NoteBox({super.key, this.boxKey, required this.icon, required this.title, this.body, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        key: boxKey,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomText(text: title, color: fg, fontSize: 11.5, fontWeight: FontWeight.w800),
              if (body != null && body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: CustomText(text: body!, color: fg, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ]),
      );
}
