import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/assessments_controller.dart';
import 'widgets/assessment_widgets.dart';
import '../../../../core/design/design.dart';

/// My assessments (`/assessments`): assessments of my classes, filtered by what needs me (marks open / upcoming / published). Creating,
/// editing, starting, cancelling, deleting, verifying and publishing are admin actions and are not offered.
class AssessmentsScreen extends GetView<AssessmentsController> {
  const AssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Assessments'),
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
        EmCaptionLine(state.hasData ? '${c.items.length} for your classes' : 'Enter marks, grade quizzes'),
        if (c.canView && state.status != SectionStatus.forbidden) ...[
          _EntryRow(key: const Key('asm_quiz_card'), icon: Icons.quiz_outlined, title: 'Online quiz grading', onTap: () => Get.toNamed(Routes.quizAttempts)),
          if (c.isClassTeacher) _EntryRow(key: const Key('asm_remarks_card'), icon: Icons.rate_review_outlined, title: 'Report card remarks', onTap: () => Get.toNamed(Routes.assessmentReportRemarks)),
        ],
        if (state.hasData) ...[
          FilterChipsRow(chips: [for (final f in AssessmentFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name)]),
          const SizedBox(height: EmSpacing.row),
          if (c.truncated.value) const EmInfoBanner(key: Key('asm_truncated'), tone: EmTone.warning, text: 'Your school has a very long assessment list: older assessments may not be shown.'),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [Padding(padding: const EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: const Key('asm_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No ${filter.label.toLowerCase()} assessments'))];
        }
        return [for (final a in visible) AssessmentTile(assessment: a, mySubjects: c.subjectsOf(a), onTap: () => Get.toNamed(Routes.assessmentDetailOf(a.id)))];
      },
    );
  }
}

/// A navigation row (icon, title, chevron) on the shared list-row card.
class _EntryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _EntryRow({super.key, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.row),
        child: EmListRow(icon: icon, title: title, trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary), onTap: onTap),
      );
}
