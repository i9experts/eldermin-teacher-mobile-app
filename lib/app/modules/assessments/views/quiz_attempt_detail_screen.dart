import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ErrorBanner;
import '../../lesson_plans/views/widgets/lesson_plan_widgets.dart' show NoteBox;
import '../controllers/quiz_controllers.dart';

/// One online quiz attempt (`/assessments/quiz-attempts/:id`): the student's answers with the answer key, and a mark for every written
/// answer (0..the question's marks). See [QuizAttemptDetailController] for the effect on the student's mark entry.
class QuizAttemptDetailScreen extends GetView<QuizAttemptDetailController> {
  const QuizAttemptDetailScreen({super.key});

  Future<void> _submit() async {
    final c = controller;
    FocusManager.instance.primaryFocus?.unfocus();
    if (c.hasErrors) {
      await c.submit();
      ToastUtil.showToast('Fix the marks in red first');
      return;
    }
    if (c.filledCount == 0) {
      await c.submit();
      return;
    }
    final a = c.attempt;
    if (!c.complete) {
      final missing = c.manualCount - c.filledCount;
      final go = await ConfirmDialog.show(
        title: 'Save partial marks?',
        message: '$missing written ${missing == 1 ? 'answer has' : 'answers have'} no mark yet. The attempt stays in your list and the total is only set once every written answer is marked.',
        confirmLabel: 'Save marks',
      );
      if (!go) return;
    } else {
      final go = await ConfirmDialog.show(
        title: 'Finish grading?',
        message: 'The total will be ${marksText(c.previewTotal ?? 0)} out of ${marksText(a?.totalMarks ?? 0)}. It becomes the mark of ${a?.studentName ?? 'the student'} for ${a?.subject ?? 'this subject'} and replaces any mark already entered there.',
        confirmLabel: 'Save and finish',
      );
      if (!go) return;
    }
    final r = await c.submit();
    switch (r) {
      case GradeSaved(:final complete):
        ToastUtil.showToast(complete ? 'Graded: the mark was recorded' : 'Marks saved');
        if (complete) Get.back();
      case GradeInvalid(:final message):
        ToastUtil.showToast(message);
      case GradeFailed():
      case GradeIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Grade attempt', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final c = controller;
        c.revision.value;
        return Column(children: [
          Expanded(
            child: ScreenStateView<QuizAttempt>(
              state: c.state.value,
              onRefresh: c.load,
              onRetry: c.load,
              emptyTitle: 'Not found',
              builder: _content,
            ),
          ),
          if (c.state.value.hasData && c.editable) _bottom(),
        ]);
      }),
    );
  }

  List<Widget> _content(QuizAttempt a) {
    final c = controller;
    return [
      CustomText(text: a.studentName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 17),
      const SizedBox(height: 3),
      CustomText(text: [a.assessmentTitle, a.subject, a.classLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 10),
      if (a.isGraded)
        NoteBox(boxKey: const Key('qa_graded_note'), icon: Icons.lock_outline_rounded, title: 'Already graded: ${marksText(a.obtainedMarks ?? 0)} out of ${marksText(a.totalMarks)}', body: "Grading again would overwrite the student's mark entry, so a graded attempt is read-only here.", fg: AppColors.amberText, bg: AppColors.amberBg)
      else
        NoteBox(
            boxKey: const Key('qa_effect_note'),
            icon: Icons.info_outline_rounded,
            title: 'How marking works',
            body: "Multiple-choice answers were marked automatically (${marksText(a.autoGradedMarks)} so far). Give each written answer a mark from 0 up to its maximum. Once every written answer is marked, the total is recorded as the student's mark for this subject and replaces any mark already there.",
            fg: AppColors.blue,
            bg: AppColors.pale),
      if (c.failure.value != null) ErrorBanner(bannerKey: const Key('qa_error'), message: c.failure.value!.message, onRetry: c.saving.value ? null : _submit),
      for (var i = 0; i < a.answers.length; i++) _answer(i + 1, a.answers[i]),
    ];
  }

  Widget _answer(int n, QuizAnswer ans) {
    final c = controller;
    final q = ans.question;
    final manual = ans.needsManualGrading;
    final error = c.showErrors.value || (c.inputs[ans.questionId] ?? '').isNotEmpty ? c.errorFor(ans.questionId) : null;
    return AppCard(
      key: ValueKey('qa_answer_${ans.questionId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: 'Question $n${q == null ? '' : ' · ${marksText(q.marks)} marks'}', color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
          if (!manual) AppTag(ans.isCorrect == true ? 'CORRECT' : 'INCORRECT', style: ans.isCorrect == true ? TagStyle.green : TagStyle.red),
        ]),
        const SizedBox(height: 4),
        CustomText(text: q?.text ?? '(Question not available)', fontWeight: FontWeight.w700, color: AppColors.black, fontSize: 13.5, height: 1.35),
        const SizedBox(height: 8),
        if (q != null && q.type == 'mcq')
          for (var i = 0; i < q.options.length; i++)
            CustomText(
                text: '${i == ans.selectedOptionIndex ? '> ' : '   '}${String.fromCharCode(65 + i)}. ${q.options[i].text}${q.options[i].isCorrect ? '  (correct)' : ''}',
                color: i == ans.selectedOptionIndex ? AppColors.primaryColor : AppColors.muted,
                fontWeight: i == ans.selectedOptionIndex ? FontWeight.w800 : FontWeight.w400,
                fontSize: 12.5)
        else ...[
          const CustomText(text: "Student's answer", color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
          const SizedBox(height: 2),
          CustomText(text: ans.textAnswer.isEmpty ? '(No answer)' : ans.textAnswer, color: AppColors.black, fontSize: 13, height: 1.4),
          if (q != null && q.correctAnswer.isNotEmpty) ...[
            const SizedBox(height: 6),
            CustomText(text: 'Model answer: ${q.correctAnswer}', color: AppColors.muted, fontSize: 12, height: 1.35),
          ],
          if (q != null && q.explanation.isNotEmpty) CustomText(text: q.explanation, color: AppColors.muted, fontSize: 12, height: 1.35),
        ],
        if (manual) ...[
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(width: 110, child: _MarkInput(key: Key('qa_mark_${ans.questionId}'), qid: ans.questionId, c: c, enabled: c.editable, hasError: error != null)),
            const SizedBox(width: 8),
            Expanded(child: CustomText(text: q == null ? '' : 'out of ${marksText(q.marks)}', color: AppColors.muted, fontSize: 12)),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: Key('qa_mark_error_${ans.questionId}'), text: error, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ] else if (ans.marksAwarded != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: '${marksText(ans.marksAwarded!)} marks (automatic)', color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _bottom() {
    final c = controller;
    final total = c.previewTotal;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(child: CustomText(key: const Key('qa_progress'), text: total != null ? 'Total ${marksText(total)} / ${marksText(c.attempt?.totalMarks ?? 0)}' : '${c.filledCount} of ${c.manualCount} marked', color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              key: const Key('qa_submit'),
              onPressed: c.saving.value || !c.hasChanges ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.buttonDisableColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
              child: c.saving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'Save marks', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MarkInput extends StatefulWidget {
  final String qid;
  final QuizAttemptDetailController c;
  final bool enabled;
  final bool hasError;
  const _MarkInput({super.key, required this.qid, required this.c, required this.enabled, required this.hasError});

  @override
  State<_MarkInput> createState() => _MarkInputState();
}

class _MarkInputState extends State<_MarkInput> {
  late final TextEditingController t = TextEditingController(text: widget.c.inputs[widget.qid] ?? '');

  @override
  void dispose() {
    t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: t,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (v) => widget.c.setMark(widget.qid, v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Marks',
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: widget.hasError ? AppColors.redText : AppColors.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: widget.hasError ? AppColors.redText : AppColors.line)),
        ),
      );
}
