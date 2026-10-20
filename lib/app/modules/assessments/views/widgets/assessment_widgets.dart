import 'package:flutter/material.dart';
import '../../../../../core/models/assessments/assessment_models.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../controllers/assessments_controller.dart';

/// Status tags of an assessment (status + published flag + online delivery).
class AssessmentTags extends StatelessWidget {
  final Assessment a;
  const AssessmentTags({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    switch (a.status) {
      case AssessmentStatus.draft:
        tags.add(const AppTag('DRAFT', style: TagStyle.amber));
      case AssessmentStatus.scheduled:
        tags.add(const AppTag('SCHEDULED', style: TagStyle.neutral));
      case AssessmentStatus.ongoing:
        tags.add(const AppTag('ONGOING', style: TagStyle.amber));
      case AssessmentStatus.completed:
        tags.add(const AppTag('COMPLETED', style: TagStyle.info));
      case AssessmentStatus.cancelled:
        tags.add(const AppTag('CANCELLED', style: TagStyle.red));
      case AssessmentStatus.published:
        break;
      default:
        if (a.status.isNotEmpty) tags.add(AppTag(a.status.toUpperCase(), style: TagStyle.neutral));
    }
    if (a.isResultPublished) tags.add(const AppTag('RESULTS PUBLISHED', style: TagStyle.green));
    if (a.isOnline) tags.add(const AppTag('ONLINE QUIZ', style: TagStyle.info));
    return Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, children: tags);
  }
}

String assessmentDateText(Assessment a) {
  final d = a.startDate;
  if (d == null) return 'Date not set';
  final e = a.endDate;
  if (e == null || (e.year == d.year && e.month == d.month && e.day == d.day)) return fullDay(d);
  return '${fullDay(d)} - ${fullDay(e)}';
}

class AssessmentTile extends StatelessWidget {
  final Assessment assessment;
  final List<String> mySubjects;
  final VoidCallback onTap;
  const AssessmentTile({super.key, required this.assessment, required this.mySubjects, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    return AppCard(
      key: ValueKey('asm_${a.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.title.isEmpty ? '(Untitled)' : a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s4),
        Text([assessmentTypeLabel(a.type), a.classLabel, if (a.term.isNotEmpty) a.term].join(' · '), style: quiet),
        Text(assessmentDateText(a), style: quiet),
        const SizedBox(height: EmSpacing.s8),
        AssessmentTags(a: a),
        if (a.status == AssessmentStatus.draft) ...[
          const SizedBox(height: EmSpacing.s8),
          Text(MarksAccess.draft.explanation, key: ValueKey('asm_draft_note_${a.id}'), style: quiet),
        ] else if (mySubjects.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          for (final s in a.subjects.where((x) => mySubjects.contains(x.subject)))
            Padding(
              padding: const EdgeInsets.only(top: EmSpacing.s2),
              child: Row(children: [
                const ExcludeSemantics(child: Icon(Icons.edit_note_rounded, size: 18, color: EmColors.primary)),
                const SizedBox(width: EmSpacing.s8),
                Expanded(child: Text('${s.subject} · out of ${marksText(s.totalMarks)}', style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
              ]),
            ),
        ] else ...[
          const SizedBox(height: EmSpacing.s8),
          Text('View only · you are the class teacher', style: quiet),
        ],
      ]),
    );
  }
}

/// An explanation box for a hard block (not my subject / online quiz): info tone, info glyph.
class AccessNote extends StatelessWidget {
  final MarksAccess access;
  final Key? noteKey;
  const AccessNote({super.key, required this.access, this.noteKey});

  @override
  Widget build(BuildContext context) => EmInfoBanner(key: noteKey, tone: EmTone.info, text: access.explanation);
}

/// The lock banner: marks cannot be changed (results published / assessment cancelled, or the server said so with 403). A lock glyph and
/// the explanation in words, in the warning tone: a locked sheet is never signalled by colour alone.
class LockBanner extends StatelessWidget {
  final String message;
  final Key? noteKey;
  const LockBanner({super.key, required this.message, this.noteKey});

  @override
  Widget build(BuildContext context) => EmInfoBanner(key: noteKey, tone: EmTone.warning, icon: Icons.lock_outline_rounded, text: message);
}

/// Bottom bar of the marks screens: a status line ("3 unsaved changes", "Total 12 / 20") and the primary button. Side by side when the
/// width allows, stacked (status above a full-width button) on a narrow phone or at a large text scale, so the status never collapses to
/// a one-word-per-line sliver.
class SaveBar extends StatelessWidget {
  final String status;
  final Key? statusKey;
  final bool muted;
  final Widget Function(bool expand) button;
  const SaveBar({super.key, required this.status, this.statusKey, this.muted = false, required this.button});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final text = Text(status, key: statusKey, style: EmType.label.copyWith(color: muted ? EmColors.textSecondary : EmColors.ink));
    return DecoratedBox(
      decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s12),
          child: LayoutBuilder(builder: (context, c) {
            final sideBySide = c.maxWidth >= 360 + (scale - 1) * 240;
            if (sideBySide) {
              return Row(children: [Expanded(child: text), const SizedBox(width: EmSpacing.row), button(false)]);
            }
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: EmSpacing.s8), button(true)]);
          }),
        ),
      ),
    );
  }
}
