import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/quiz_controllers.dart';
import '../../../../core/design/design.dart';

/// Online quiz attempts waiting for a teacher (`/assessments/quiz-attempts`): written answers that need a mark, for my classes and subjects.
class QuizAttemptsScreen extends GetView<QuizAttemptsController> {
  const QuizAttemptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Quiz grading'),
      body: Obx(() {
        final c = controller;
        final state = c.state.value;
        return ScreenStateView<List<QuizAttempt>>(
          state: c.canView ? state : const SectionState<List<QuizAttempt>>.forbidden(),
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          emptyIcon: c.hasNoScope && c.canView ? Icons.school_outlined : Icons.task_alt_rounded,
          emptyTitle: c.hasNoScope ? "You aren't assigned to a class or subject" : 'Nothing waiting for your marks',
          emptySubtitle: c.hasNoScope
              ? "Quiz attempts are shown for the class you are class teacher of (all subjects) and for the subjects you teach in your other classes. You don't have either yet, so there is nothing to show. Ask your school admin if this looks wrong."
              : 'Attempts appear here for every subject of your own class (if you are a class teacher) and for the subjects you teach in your other classes. When a student submits an online quiz with written answers, it shows up here.',
          header: [
            EmCaptionLine(state.hasData ? '${c.items.length} waiting for review · your class and your subjects' : 'Written answers to mark'),
            if (state.hasData) _chips(c),
          ],
          builder: (_) => [for (final a in c.visible) _tile(a)],
        );
      }),
    );
  }

  Widget _chips(QuizAttemptsController c) {
    final selected = c.subjectFilter.value;
    return SingleChildScrollView(
      key: const Key('quiz_subject_chips'),
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final s in <String?>[null, ...c.subjects])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8),
            child: EmChip(
              key: Key('quiz_chip_${s ?? 'all'}'),
              label: '${s ?? 'All'} (${c.countFor(s)})',
              selected: s == null ? selected == null : selected?.toLowerCase() == s.toLowerCase(),
              onTap: () => c.setSubjectFilter(s),
            ),
          ),
      ]),
    );
  }

  Widget _tile(QuizAttempt a) {
    final pending = a.pendingCount;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    return AppCard(
      key: ValueKey('qa_${a.id}'),
      onTap: () => Get.toNamed(Routes.quizAttemptDetailOf(a.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(a.studentName.isEmpty ? '(Student)' : a.studentName, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag(pending == 1 ? '1 ANSWER TO MARK' : '$pending ANSWERS TO MARK', style: TagStyle.amber),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text([a.assessmentTitle, a.subject, a.classLabel].where((e) => e.isNotEmpty).join(' · '), style: quiet),
        if (a.submittedAt != null) Text('Submitted ${instantText(a.submittedAt!)}${a.attemptNumber > 1 ? ' · attempt ${a.attemptNumber}' : ''}', style: quiet),
      ]),
    );
  }
}
