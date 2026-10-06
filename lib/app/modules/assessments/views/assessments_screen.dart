import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/assessments_controller.dart';
import 'widgets/assessment_widgets.dart';

/// My assessments (`/assessments`): assessments of my classes, filtered by what needs me (marks open / upcoming / published). Creating,
/// editing, starting, cancelling, deleting, verifying and publishing are admin actions and are not offered.
class AssessmentsScreen extends GetView<AssessmentsController> {
  const AssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Assessments', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state.value;
    final filter = c.filter.value;
    final visible = c.filtered;
    return ScreenStateView<List<Assessment>>(
      state: c.canView ? state : const SectionState<List<Assessment>>.forbidden(),
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.fact_check_outlined,
      emptyTitle: 'No assessments for your classes yet',
      emptySubtitle: 'Your school schedules assessments per class. Once one covers a class and subject you teach, it appears here.',
      header: [
        ScreenHeader(title: 'Assessments & marks', caption: state.hasData ? '${c.items.length} for your classes' : 'Enter marks, grade quizzes'),
        if (c.canView && state.status != SectionStatus.forbidden) ...[
          AppCard(
            key: const Key('asm_quiz_card'),
            onTap: () => Get.toNamed(Routes.quizAttempts),
            child: const Row(children: [
              Icon(Icons.quiz_outlined, color: AppColors.primaryColor),
              SizedBox(width: 10),
              Expanded(child: CustomText(text: 'Online quiz grading', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ),
          if (c.isClassTeacher)
            AppCard(
              key: const Key('asm_remarks_card'),
              onTap: () => Get.toNamed(Routes.assessmentReportRemarks),
              child: const Row(children: [
                Icon(Icons.rate_review_outlined, color: AppColors.primaryColor),
                SizedBox(width: 10),
                Expanded(child: CustomText(text: 'Report card remarks', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
        ],
        if (state.hasData) ...[
          FilterChipsRow(chips: [for (final f in AssessmentFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name)]),
          const SizedBox(height: 10),
          if (c.truncated.value)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: CustomText(key: Key('asm_truncated'), text: 'Your school has a very long assessment list: older assessments may not be shown.', color: AppColors.amberText, fontSize: 12),
            ),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [Padding(padding: const EdgeInsets.only(top: 24), child: AppEmptyView(key: const Key('asm_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No ${filter.label.toLowerCase()} assessments'))];
        }
        return [for (final a in visible) AssessmentTile(assessment: a, mySubjects: c.subjectsOf(a), onTap: () => Get.toNamed(Routes.assessmentDetailOf(a.id)))];
      },
    );
  }
}
