import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';

/// Merit = success tone, concern = error tone, note = neutral. Each kind also has its own glyph ([kindIcon]) and label.
EmTone kindTone(BehaviourKind? k) => switch (k) {
      BehaviourKind.merit => EmTone.success,
      BehaviourKind.demerit => EmTone.error,
      _ => EmTone.neutral,
    };

Color kindColor(BehaviourKind? k) => kindTone(k).foreground;

Color kindBg(BehaviourKind? k) => kindTone(k).background;

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
    final meta = [if (r.day != null) shortDay(r.day!), if (r.classLabel.isNotEmpty && showStudent) r.classLabel, mine ? 'You' : r.reportedBy].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      key: ValueKey('rec_${r.id}'),
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        onTap: onTap,
        padding: EmSpacing.cardPadCompact,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: kindBg(k), shape: BoxShape.circle),
            child: ExcludeSemantics(child: Icon(kindIcon(k), size: 22, color: kindColor(k))),
          ),
          const SizedBox(width: EmSpacing.row),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showStudent) Text(r.studentName.isEmpty ? 'Student' : r.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
              Text(
                r.title.isEmpty ? categoryLabel(r.category) : r.title,
                style: showStudent ? EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400) : EmType.bodyLarge.copyWith(color: EmColors.ink),
              ),
              if (r.description.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
              const SizedBox(height: EmSpacing.s8),
              Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (r.category.isNotEmpty) AppTag(categoryLabel(r.category).toUpperCase(), style: EmTone.neutral),
                if (k == BehaviourKind.demerit && (r.severity == 'high' || r.severity == 'critical')) AppTag(r.severity.toUpperCase(), style: EmTone.error),
                if (r.resolved) const AppTag('RESOLVED', style: EmTone.success),
                if (meta.isNotEmpty) Text(meta, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
              ]),
            ]),
          ),
          if (r.points != 0) Padding(padding: const EdgeInsetsDirectional.only(start: EmSpacing.s8), child: Text(pointsText(r.points), style: EmType.value.copyWith(color: kindColor(k)))),
        ]),
      ),
    );
  }
}

/// "Parents can see this" notice: the parent app shows every behaviour record of a student (parent-portal.service.ts:390-396).
class ParentVisibleNote extends StatelessWidget {
  final String text;
  const ParentVisibleNote({super.key, this.text = "Parents can see what you log here in their app."});

  @override
  Widget build(BuildContext context) => EmInfoBanner(key: const Key('parent_visible_note'), tone: EmTone.warning, icon: Icons.visibility_outlined, text: text);
}

class TarbiyahCard extends StatelessWidget {
  final TarbiyahAssessment a;

  /// The school's programme: trait labels come from it (built-in Tarbiyah names, then the raw key, as the fallback).
  final CharacterSettings settings;

  /// Set only for an assessment I recorded and may edit (the server enforces the author rule too).
  final VoidCallback? onEdit;
  const TarbiyahCard({super.key, required this.a, this.settings = CharacterSettings.fallback, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final style = switch (a.overallRating) {
      'excellent' || 'good' => EmTone.success,
      'satisfactory' => EmTone.warning,
      'needs_improvement' || 'critical' => EmTone.error,
      _ => EmTone.neutral,
    };
    return AppCard(
      key: ValueKey('tarbiyah_${a.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(a.period.isEmpty ? 'Assessment' : a.period, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          if (a.ratingLabel.isNotEmpty) AppTag(a.ratingLabel.toUpperCase(), style: style),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text('${a.overallPercentage.round()}% overall${a.day == null ? '' : ' · ${fullDay(a.day!)}'}${a.assessedBy.isEmpty ? '' : ' · ${a.assessedBy}'}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        if (a.traits.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s12),
          for (final t in a.traits)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.s4),
              child: Row(children: [
                Expanded(child: Text(settings.labelFor(t.key), style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400))),
                Text(markText(t.score), style: EmType.valueSmall.copyWith(color: EmColors.ink)),
              ]),
            ),
        ],
        if (a.teacherObservations.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          Text(a.teacherObservations, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.4)),
        ],
        if (onEdit != null) ...[
          const SizedBox(height: EmSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: EmTextAction(key: ValueKey('tarbiyah_edit_${a.id}'), icon: Icons.edit_outlined, label: 'Edit', onPressed: onEdit),
          ),
        ],
      ]),
    );
  }
}
