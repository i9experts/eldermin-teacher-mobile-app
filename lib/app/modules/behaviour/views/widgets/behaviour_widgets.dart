import 'package:flutter/material.dart';
import '../../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';

Color kindColor(BehaviourKind? k) => switch (k) {
      BehaviourKind.merit => AppColors.greenText,
      BehaviourKind.demerit => AppColors.redText,
      _ => AppColors.muted,
    };

Color kindBg(BehaviourKind? k) => switch (k) {
      BehaviourKind.merit => AppColors.greenBg,
      BehaviourKind.demerit => AppColors.redBg,
      _ => AppColors.pale,
    };

IconData kindIcon(BehaviourKind? k) => switch (k) {
      BehaviourKind.merit => Icons.emoji_events_rounded,
      BehaviourKind.demerit => Icons.report_gmailerrorred_rounded,
      _ => Icons.sticky_note_2_outlined,
    };

String pointsText(int p) => p > 0 ? '+$p' : '$p';

/// One behaviour record.
class BehaviourTile extends StatelessWidget {
  final BehaviourRecord record;
  final bool mine;
  final bool showStudent;
  final VoidCallback? onTap;
  const BehaviourTile({super.key, required this.record, required this.mine, this.showStudent = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final k = r.kind;
    return AppCard(
      key: ValueKey('rec_${r.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: kindBg(k), borderRadius: BorderRadius.circular(12)),
          child: Icon(kindIcon(k), size: 20, color: kindColor(k)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showStudent)
              CustomText(text: r.studentName.isEmpty ? 'Student' : r.studentName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
            CustomText(text: r.title.isEmpty ? categoryLabel(r.category) : r.title, fontWeight: showStudent ? FontWeight.w600 : FontWeight.w800, color: showStudent ? AppColors.black : AppColors.primaryColor, fontSize: 12.5, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (r.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: CustomText(text: r.description, color: AppColors.muted, fontSize: 11.5, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (r.category.isNotEmpty) AppTag(categoryLabel(r.category).toUpperCase(), style: TagStyle.neutral),
              if (k == BehaviourKind.demerit && (r.severity == 'high' || r.severity == 'critical')) AppTag(r.severity.toUpperCase(), style: TagStyle.red),
              if (r.resolved) const AppTag('RESOLVED', style: TagStyle.green),
              CustomText(text: [if (r.day != null) shortDay(r.day!), if (r.classLabel.isNotEmpty && showStudent) r.classLabel, mine ? 'You' : r.reportedBy].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 10.5),
            ]),
          ]),
        ),
        if (r.points != 0) Padding(padding: const EdgeInsets.only(left: 8), child: CustomText(text: pointsText(r.points), fontWeight: FontWeight.w800, color: kindColor(k), fontSize: 14)),
      ]),
    );
  }
}

/// "Parents can see this" notice: the parent app shows every behaviour record of a student (parent-portal.service.ts:390-396).
class ParentVisibleNote extends StatelessWidget {
  final String text;
  const ParentVisibleNote({super.key, this.text = "Parents can see what you log here in their app."});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('parent_visible_note'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.visibility_outlined, size: 16, color: AppColors.amberText),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: text, color: AppColors.amberText, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.35)),
        ]),
      );
}

class TarbiyahCard extends StatelessWidget {
  final TarbiyahAssessment a;
  const TarbiyahCard({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final style = switch (a.overallRating) {
      'excellent' || 'good' => TagStyle.green,
      'satisfactory' => TagStyle.amber,
      'needs_improvement' || 'critical' => TagStyle.red,
      _ => TagStyle.neutral,
    };
    return AppCard(
      key: ValueKey('tarbiyah_${a.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: a.period.isEmpty ? 'Assessment' : a.period, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13)),
          if (a.ratingLabel.isNotEmpty) AppTag(a.ratingLabel.toUpperCase(), style: style),
        ]),
        const SizedBox(height: 4),
        CustomText(text: '${a.overallPercentage.round()}% overall${a.day == null ? '' : ' · ${fullDay(a.day!)}'}${a.assessedBy.isEmpty ? '' : ' · ${a.assessedBy}'}', color: AppColors.muted, fontSize: 11),
        if (a.traits.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final t in a.traits)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Expanded(child: CustomText(text: t.label, fontSize: 11.5)),
                CustomText(text: markText(t.score), fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 12),
              ]),
            ),
        ],
        if (a.teacherObservations.isNotEmpty) ...[const SizedBox(height: 6), CustomText(text: a.teacherObservations, color: AppColors.black, fontSize: 11.5, height: 1.35)],
      ]),
    );
  }
}
