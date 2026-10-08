import 'package:flutter/material.dart';
import '../../../../../core/models/assessments/assessment_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';
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
    return Wrap(spacing: 4, runSpacing: 4, children: tags);
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
    return AppCard(
      key: ValueKey('asm_${a.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomText(text: a.title.isEmpty ? '(Untitled)' : a.title, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        CustomText(text: [assessmentTypeLabel(a.type), a.classLabel, if (a.term.isNotEmpty) a.term].join(' · '), color: AppColors.muted, fontSize: 11.5),
        const SizedBox(height: 2),
        CustomText(text: assessmentDateText(a), color: AppColors.muted, fontSize: 11.5),
        const SizedBox(height: 8),
        AssessmentTags(a: a),
        if (a.status == AssessmentStatus.draft) ...[
          const SizedBox(height: 8),
          CustomText(key: ValueKey('asm_draft_note_${a.id}'), text: MarksAccess.draft.explanation, color: AppColors.muted, fontSize: 11.5),
        ] else if (mySubjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final s in a.subjects.where((x) => mySubjects.contains(x.subject)))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                const Icon(Icons.edit_note_rounded, size: 15, color: AppColors.blue),
                const SizedBox(width: 6),
                Expanded(child: CustomText(text: '${s.subject} · out of ${marksText(s.totalMarks)}', color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ] else ...[
          const SizedBox(height: 6),
          const CustomText(text: 'View only · you are the class teacher', color: AppColors.muted, fontSize: 11.5),
        ],
      ]),
    );
  }
}

/// A blue explanation box for a hard block (not my subject / online quiz).
class AccessNote extends StatelessWidget {
  final MarksAccess access;
  final Key? noteKey;
  const AccessNote({super.key, required this.access, this.noteKey});

  @override
  Widget build(BuildContext context) => _NoteBox(noteKey: noteKey, text: access.explanation, warning: false);
}

/// The red lock banner: marks cannot be changed (results published / assessment cancelled, or the server said so with 403).
class LockBanner extends StatelessWidget {
  final String message;
  final Key? noteKey;
  const LockBanner({super.key, required this.message, this.noteKey});

  @override
  Widget build(BuildContext context) => Container(
        key: noteKey,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.amberText)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.amberText),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: message, color: AppColors.amberText, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _NoteBox extends StatelessWidget {
  final Key? noteKey;
  final String text;
  final bool warning;
  const _NoteBox({this.noteKey, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: noteKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warning ? AppColors.amberBg : AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded, size: 18, color: warning ? AppColors.amberText : AppColors.blue),
        const SizedBox(width: 8),
        Expanded(child: CustomText(text: text, color: warning ? AppColors.amberText : AppColors.blue, fontSize: 12.5, height: 1.35)),
      ]),
    );
  }
}
