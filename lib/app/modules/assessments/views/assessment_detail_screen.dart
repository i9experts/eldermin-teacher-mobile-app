import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/assessments_controller.dart';
import 'widgets/assessment_widgets.dart';
import '../../../../core/design/design.dart';

/// One assessment (`/assessments/:id`): its subjects with total / pass marks, which ones I mark, and the entry points (marks grid, online
/// quiz review, report-card remarks). No create / edit / status / delete / publish.
class AssessmentDetailScreen extends GetView<AssessmentDetailController> {
  const AssessmentDetailScreen({super.key});

  AssessmentsController get list => controller.list;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Assessment'),
      body: Obx(() {
        final c = controller;
        final fromList = list.byId(c.id);
        final state = fromList != null ? SectionState<Assessment>.data(fromList) : c.state.value;
        return ScreenStateView<Assessment>(
          state: state,
          onRefresh: () => c.load(force: true),
          onRetry: () => c.load(force: true),
          emptyTitle: 'Not found',
          builder: (a) => _content(a),
        );
      }),
    );
  }

  List<Widget> _content(Assessment a) {
    final mySubjects = list.subjectsOf(a);
    final quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400);
    return [
      Text(a.title, style: EmType.title.copyWith(color: EmColors.ink)),
      const SizedBox(height: EmSpacing.s4),
      Text([assessmentTypeLabel(a.type), a.classLabel, if (a.term.isNotEmpty) a.term, if (a.academicYear.isNotEmpty) a.academicYear].join(' · '), style: quiet),
      Text(assessmentDateText(a), style: quiet),
      const SizedBox(height: EmSpacing.s8),
      AssessmentTags(a: a),
      if (a.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.row), child: Text(a.description, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5))),
      const SizedBox(height: EmSpacing.s8),
      const SectionRow(title: 'Subjects'),
      for (final s in a.subjects) _subjectCard(a, s, mySubjects.contains(s.subject)),
      if (list.canWriteRemarks(a)) ...[
        const SizedBox(height: EmSpacing.s4),
        EmListRow(
          key: const Key('asm_detail_remarks'),
          icon: Icons.rate_review_outlined,
          title: 'Report card remarks for your class',
          trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
          onTap: () => Get.toNamed(Routes.assessmentReportRemarksOf(a.id)),
        ),
      ],
    ];
  }

  Widget _subjectCard(Assessment a, AssessmentSubject s, bool mine) {
    final access = list.accessFor(a, s);
    final when = [if (s.date != null) shortDay(s.date!), if (s.startTime.isNotEmpty) s.startTime, if (s.duration != null) '${s.duration} min', if (s.venue.isNotEmpty) s.venue].join(' · ');
    final sections = list.myClasses;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    return AppCard(
      key: ValueKey('asm_subject_${s.subject}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(s.subject, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          if (mine) ...[const SizedBox(width: EmSpacing.s8), const AppTag('YOUR SUBJECT', style: TagStyle.info)],
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text('Out of ${marksText(s.totalMarks)} · pass ${marksText(s.passingMarks)}', style: quiet),
        if (when.isNotEmpty) Text(when, style: quiet),
        if (s.examiner.isNotEmpty) Text('Examiner: ${s.examiner}', style: quiet),
        if (mine || sections.any((c) => c.isClassTeacherClass)) ...[
          const SizedBox(height: EmSpacing.s8),
          if (access.canEdit)
            _action(Key('asm_marks_${s.subject}'), Icons.edit_note_rounded, 'Enter marks', () => Get.toNamed(Routes.assessmentMarksOf(a.id, subject: s.subject)))
          else if (access == MarksAccess.draft)
            Text(access.explanation, key: Key('asm_draft_${s.subject}'), style: quiet.copyWith(height: 1.4))
          else ...[
            if (access == MarksAccess.onlineQuiz)
              _action(Key('asm_quiz_${s.subject}'), Icons.quiz_outlined, 'Review online quiz answers', () => Get.toNamed(Routes.quizAttempts))
            else
              // a locked subject says so with a lock glyph and words (never colour alone)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const ExcludeSemantics(child: Icon(Icons.lock_outline_rounded, size: 18, color: EmColors.onWarningContainer)),
                const SizedBox(width: EmSpacing.s8),
                Expanded(child: Text(access == MarksAccess.locked ? (marksLockMessage(a) ?? access.explanation) : access.explanation, key: Key('asm_locked_${s.subject}'), style: quiet.copyWith(height: 1.4))),
              ]),
            _action(Key('asm_view_${s.subject}'), Icons.visibility_outlined, 'View marks', () => Get.toNamed(Routes.assessmentMarksOf(a.id, subject: s.subject))),
          ],
        ],
      ]),
    );
  }

  /// A tappable action row of a subject card (48dp, label wraps rather than clips).
  Widget _action(Key key, IconData icon, String label, VoidCallback onTap) => InkWell(
        key: key,
        onTap: onTap,
        borderRadius: EmRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
          child: Row(children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: EmColors.primary)),
            const SizedBox(width: EmSpacing.s8),
            Expanded(child: Text(label, style: EmType.label.copyWith(color: EmColors.primary))),
            const ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary)),
          ]),
        ),
      );
}
