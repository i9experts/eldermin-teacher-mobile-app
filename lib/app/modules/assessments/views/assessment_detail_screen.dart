import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/assessments_controller.dart';
import 'widgets/assessment_widgets.dart';

/// One assessment (`/assessments/:id`): its subjects with total / pass marks, which ones I mark, and the entry points (marks grid, online
/// quiz review, report-card remarks). No create / edit / status / delete / publish.
class AssessmentDetailScreen extends GetView<AssessmentDetailController> {
  const AssessmentDetailScreen({super.key});

  AssessmentsController get list => controller.list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Assessment', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
    return [
      CustomText(text: a.title, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 18),
      const SizedBox(height: 4),
      CustomText(text: [assessmentTypeLabel(a.type), a.classLabel, if (a.term.isNotEmpty) a.term, if (a.academicYear.isNotEmpty) a.academicYear].join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 2),
      CustomText(text: assessmentDateText(a), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 8),
      AssessmentTags(a: a),
      if (a.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: CustomText(text: a.description, color: AppColors.black, fontSize: 12.5, height: 1.4)),
      const SizedBox(height: 14),
      const SubHeading('Subjects'),
      for (final s in a.subjects) _subjectCard(a, s, mySubjects.contains(s.subject)),
      if (list.canWriteRemarks(a)) ...[
        const SizedBox(height: 4),
        AppCard(
          key: const Key('asm_detail_remarks'),
          onTap: () => Get.toNamed(Routes.assessmentReportRemarksOf(a.id)),
          child: const Row(children: [
            Icon(Icons.rate_review_outlined, color: AppColors.primaryColor),
            SizedBox(width: 10),
            Expanded(child: CustomText(text: 'Report card remarks for your class', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13)),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ],
    ];
  }

  Widget _subjectCard(Assessment a, AssessmentSubject s, bool mine) {
    final access = list.accessFor(a, s);
    final when = [if (s.date != null) shortDay(s.date!), if (s.startTime.isNotEmpty) s.startTime, if (s.duration != null) '${s.duration} min', if (s.venue.isNotEmpty) s.venue].join(' · ');
    final sections = list.myClasses;
    return AppCard(
      key: ValueKey('asm_subject_${s.subject}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: s.subject, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14)),
          if (mine) const AppTag('YOUR SUBJECT', style: TagStyle.info),
        ]),
        const SizedBox(height: 3),
        CustomText(text: 'Out of ${marksText(s.totalMarks)} · pass ${marksText(s.passingMarks)}', color: AppColors.muted, fontSize: 12),
        if (when.isNotEmpty) CustomText(text: when, color: AppColors.muted, fontSize: 12),
        if (s.examiner.isNotEmpty) CustomText(text: 'Examiner: ${s.examiner}', color: AppColors.muted, fontSize: 12),
        if (mine || sections.any((c) => c.isClassTeacherClass)) ...[
          const SizedBox(height: 8),
          if (access.canEdit)
            _action(Key('asm_marks_${s.subject}'), Icons.edit_note_rounded, 'Enter marks', () => Get.toNamed(Routes.assessmentMarksOf(a.id, subject: s.subject)))
          else ...[
            if (access == MarksAccess.onlineQuiz)
              _action(Key('asm_quiz_${s.subject}'), Icons.quiz_outlined, 'Review online quiz answers', () => Get.toNamed(Routes.quizAttempts))
            else
              CustomText(key: Key('asm_locked_${s.subject}'), text: access.explanation, color: AppColors.muted, fontSize: 12, height: 1.35),
            if (access != MarksAccess.notOpenYet && access != MarksAccess.cancelled)
              _action(Key('asm_view_${s.subject}'), Icons.visibility_outlined, 'View marks', () => Get.toNamed(Routes.assessmentMarksOf(a.id, subject: s.subject))),
          ],
        ],
      ]),
    );
  }

  Widget _action(Key key, IconData icon, String label, VoidCallback onTap) => InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.blue),
            const SizedBox(width: 8),
            Expanded(child: CustomText(text: label, color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 13)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      );
}
