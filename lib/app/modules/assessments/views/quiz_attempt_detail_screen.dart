import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ErrorBanner;
import '../../lesson_plans/views/widgets/lesson_plan_widgets.dart' show NoteBox;
import '../controllers/quiz_controllers.dart';
import 'widgets/assessment_widgets.dart' show LockBanner, SaveBar;
import '../../../../core/design/design.dart';

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
    return EmScaffold(
      appBar: EmAppBar(title: 'Grade attempt'),
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
      Text(a.studentName, style: EmType.title.copyWith(color: EmColors.ink)),
      EmCaptionLine([a.assessmentTitle, a.subject, a.classLabel].where((e) => e.isNotEmpty).join(' · ')),
      if (c.lockMessage.value != null)
        LockBanner(noteKey: const Key('qa_lock_banner'), message: c.lockMessage.value!)
      else if (a.isGraded)
        NoteBox(boxKey: const Key('qa_graded_note'), icon: Icons.lock_outline_rounded, title: 'Already graded: ${marksText(a.obtainedMarks ?? 0)} out of ${marksText(a.totalMarks)}', body: "Grading again would overwrite the student's mark entry, so a graded attempt is read-only here.", tone: EmTone.warning)
      else
        NoteBox(
            boxKey: const Key('qa_effect_note'),
            icon: Icons.info_outline_rounded,
            title: 'How marking works',
            body: "Multiple-choice answers were marked automatically (${marksText(a.autoGradedMarks)} so far). Give each written answer a mark from 0 up to its maximum. Once every written answer is marked, the total is recorded as the student's mark for this subject and replaces any mark already there.",
            tone: EmTone.info),
      if (c.failure.value != null) ErrorBanner(bannerKey: const Key('qa_error'), message: c.failure.value!.message, onRetry: c.saving.value || !c.failure.value!.canRetry ? null : _submit),
      for (var i = 0; i < a.answers.length; i++) _answer(i + 1, a.answers[i]),
    ];
  }

  Widget _answer(int n, QuizAnswer ans) {
    final c = controller;
    final q = ans.question;
    final manual = ans.needsManualGrading;
    final error = c.showErrors.value || (c.inputs[ans.questionId] ?? '').isNotEmpty ? c.errorFor(ans.questionId) : null;
    final quiet = EmType.caption.copyWith(color: EmColors.textSecondary);
    final body = EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5);
    return AppCard(
      key: ValueKey('qa_answer_${ans.questionId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('Question $n${q == null ? '' : ' · ${marksText(q.marks)} marks'}', style: quiet.copyWith(fontWeight: FontWeight.w600))),
          if (!manual) ...[const SizedBox(width: EmSpacing.s8), AppTag(ans.isCorrect == true ? 'CORRECT' : 'INCORRECT', style: ans.isCorrect == true ? TagStyle.green : TagStyle.red)],
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text(q?.text ?? '(Question not available)', style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: EmSpacing.s8),
        if (q != null && q.type == 'mcq')
          for (var i = 0; i < q.options.length; i++)
            // the chosen option is marked with '>' and bold, the correct one says "(correct)": never colour alone
            Text(
                '${i == ans.selectedOptionIndex ? '> ' : '   '}${String.fromCharCode(65 + i)}. ${q.options[i].text}${q.options[i].isCorrect ? '  (correct)' : ''}',
                style: EmType.body.copyWith(color: i == ans.selectedOptionIndex ? EmColors.ink : EmColors.textSecondary, fontWeight: i == ans.selectedOptionIndex ? FontWeight.w700 : FontWeight.w400))
        else ...[
          Text("Student's answer", style: quiet.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: EmSpacing.s2),
          Text(ans.textAnswer.isEmpty ? '(No answer)' : ans.textAnswer, style: body),
          if (q != null && q.correctAnswer.isNotEmpty) ...[
            const SizedBox(height: EmSpacing.s8),
            Text('Model answer: ${q.correctAnswer}', style: quiet.copyWith(height: 1.4)),
          ],
          if (q != null && q.explanation.isNotEmpty) Text(q.explanation, style: quiet.copyWith(height: 1.4)),
        ],
        if (manual) ...[
          const SizedBox(height: EmSpacing.row),
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 128, child: _MarkInput(key: Key('qa_mark_${ans.questionId}'), qid: ans.questionId, c: c, enabled: c.editable, hasError: error != null)),
            Text(q == null ? '' : 'out of ${marksText(q.marks)}', style: EmType.body.copyWith(color: EmColors.textSecondary)),
          ]),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: EmSpacing.s8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const ExcludeSemantics(child: Icon(Icons.error_outline_rounded, size: 16, color: EmColors.error)),
                const SizedBox(width: EmSpacing.s4),
                Expanded(child: Text(error, key: Key('qa_mark_error_${ans.questionId}'), style: quiet.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
              ]),
            ),
        ] else if (ans.marksAwarded != null)
          Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('${marksText(ans.marksAwarded!)} marks (automatic)', style: quiet)),
      ]),
    );
  }

  Widget _bottom() {
    final c = controller;
    final total = c.previewTotal;
    return SaveBar(
      statusKey: const Key('qa_progress'),
      status: total != null ? 'Total ${marksText(total)} / ${marksText(c.attempt?.totalMarks ?? 0)}' : '${c.filledCount} of ${c.manualCount} marked',
      button: (expand) => EmPrimaryButton(key: const Key('qa_submit'), expand: expand, loading: c.saving.value, label: 'Save marks', onPressed: c.saving.value || !c.hasChanges ? null : _submit),
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

  OutlineInputBorder _border() => OutlineInputBorder(borderRadius: EmRadius.smAll, borderSide: BorderSide(color: widget.hasError ? EmColors.error : EmColors.border));

  @override
  Widget build(BuildContext context) => TextField(
        controller: t,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        textInputAction: TextInputAction.next,
        onChanged: (v) => widget.c.setMark(widget.qid, v),
        style: EmType.valueSmall.copyWith(color: EmColors.ink),
        decoration: InputDecoration(isDense: true, hintText: 'Marks', border: _border(), enabledBorder: _border(), focusedBorder: widget.hasError ? _border() : null),
      );
}
