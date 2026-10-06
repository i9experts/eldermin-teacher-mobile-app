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
import '../controllers/quiz_controllers.dart';

/// Online quiz attempts waiting for a teacher (`/assessments/quiz-attempts`): written answers that need a mark, for my classes and subjects.
class QuizAttemptsScreen extends GetView<QuizAttemptsController> {
  const QuizAttemptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Quiz grading', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final c = controller;
        final state = c.state.value;
        return ScreenStateView<List<QuizAttempt>>(
          state: c.canView ? state : const SectionState<List<QuizAttempt>>.forbidden(),
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          emptyIcon: Icons.task_alt_rounded,
          emptyTitle: 'Nothing waiting for your marks',
          emptySubtitle: 'Only attempts from your classes (and the subjects you teach there) are shown. When one of your students submits an online quiz with written answers, it appears here.',
          header: [ScreenHeader(title: 'Quiz grading', caption: state.hasData ? '${c.items.length} waiting for review · only your classes are shown' : 'Written answers to mark')],
          builder: (items) => [for (final a in items) _tile(a)],
        );
      }),
    );
  }

  Widget _tile(QuizAttempt a) {
    final pending = a.pendingCount;
    return AppCard(
      key: ValueKey('qa_${a.id}'),
      onTap: () => Get.toNamed(Routes.quizAttemptDetailOf(a.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: a.studentName.isEmpty ? '(Student)' : a.studentName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14)),
          AppTag(pending == 1 ? '1 ANSWER TO MARK' : '$pending ANSWERS TO MARK', style: TagStyle.amber),
        ]),
        const SizedBox(height: 3),
        CustomText(text: [a.assessmentTitle, a.subject, a.classLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
        if (a.submittedAt != null) CustomText(text: 'Submitted ${instantText(a.submittedAt!)}${a.attemptNumber > 1 ? ' · attempt ${a.attemptNumber}' : ''}', color: AppColors.muted, fontSize: 11.5),
      ]),
    );
  }
}
