import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../utils/toast_util.dart';
import '../controllers/submissions_controller.dart';
import 'widgets/homework_widgets.dart';
import '../../../../core/design/design.dart';

/// Grade one submission (`/homework/:id/submissions/:sid/grade`): the student's answer and files, marks out of the maximum, feedback.
/// Validates 0..max before sending and shows the server's own rejection text if it still says no.
class HomeworkGradeScreen extends StatefulWidget {
  const HomeworkGradeScreen({super.key});

  @override
  State<HomeworkGradeScreen> createState() => _HomeworkGradeScreenState();
}

class _HomeworkGradeScreenState extends State<HomeworkGradeScreen> {
  final marks = TextEditingController();
  final feedback = TextEditingController();
  String? error;
  String? serverError;
  bool seeded = false;
  late final String sid = Get.parameters['sid'] ?? '';
  SubmissionsController get c => Get.find<SubmissionsController>();

  @override
  void dispose() {
    marks.dispose();
    feedback.dispose();
    super.dispose();
  }

  void _seed(Submission s) {
    if (seeded) return;
    seeded = true;
    if (s.grade != null) marks.text = markText(s.grade!);
    feedback.text = s.feedback;
  }

  Future<void> _save(Submission s) async {
    setState(() {
      error = null;
      serverError = null;
    });
    final r = await c.grade(s.id, marks.text, feedback.text);
    if (!mounted) return;
    switch (r) {
      case GradeSaved():
        ToastUtil.showToast('Marks saved');
        Get.back();
      case GradeInvalid(:final message):
        setState(() => error = message);
      case GradeFailed(:final failure):
        setState(() => serverError = failure.message);
      case GradeIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Grade submission'),
      body: Obx(() {
        final state = c.state.value;
        final s = c.byId(sid);
        final saving = c.savingId.value == sid;
        final opening = c.openingKey.value;
        if (state.hasData && s == null) {
          return const AppEmptyView(key: Key('grade_missing'), icon: Icons.search_off_rounded, title: 'Submission not found', subtitle: 'It may have been removed. Go back and refresh the list.');
        }
        return ScreenStateView<SubmissionsResult>(
          state: state,
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          builder: (_) => _content(s!, saving, opening),
        );
      }),
    );
  }

  List<Widget> _content(Submission s, bool saving, String? opening) {
    _seed(s);
    final gradable = c.canGrade(s);
    final max = markText(s.maxGrade);
    final body = EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5);
    final quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400);
    return [
      Text(s.studentName.isEmpty ? 'Student' : s.studentName, key: const Key('grade_student'), style: EmType.title.copyWith(color: EmColors.ink)),
      const SizedBox(height: EmSpacing.s8),
      SubmissionTags(s: s),
      if (s.submittedAt != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('Handed in ${instantText(s.submittedAt!)}', style: EmType.caption.copyWith(color: EmColors.textSecondary))),
      const SizedBox(height: EmSpacing.s8),
      const SubHeading('Answer'),
      AppCard(
        child: s.textResponse.isEmpty ? Text('No written answer.', key: const Key('grade_no_text'), style: quiet) : Text(s.textResponse, key: const Key('grade_text'), style: body),
      ),
      if (s.attachmentKeys.isNotEmpty) ...[
        const SubHeading('Files'),
        for (var i = 0; i < s.attachmentKeys.length; i++)
          AttachmentLink(
            key: ValueKey('grade_att_$i'),
            label: attachmentLabel(s.attachmentKeys[i], i),
            busy: opening == s.attachmentKeys[i],
            onTap: () async {
              final f = await c.openAttachment(s.attachmentKeys[i]);
              if (f != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
            },
          ),
      ],
      const SubHeading('Marks'),
      if (!gradable)
        AppCard(child: Text('Nothing has been handed in yet, so there is nothing to grade.', key: const Key('grade_not_gradable'), style: quiet))
      else ...[
        if (serverError != null) ErrorBanner(bannerKey: const Key('grade_server_error'), message: serverError!),
        LabeledField(
          label: 'Marks out of $max',
          required: true,
          controller: marks,
          fieldKey: const Key('grade_marks'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: error,
          onChanged: (_) => setState(() => error = null),
        ),
        LabeledField(label: 'Feedback for the student', controller: feedback, fieldKey: const Key('grade_feedback'), maxLines: 3, hint: 'Optional'),
        EmPrimaryButton(key: const Key('grade_save'), loading: saving, label: s.isGraded ? 'Update marks' : 'Save marks', onPressed: saving ? null : () => _save(s)),
        Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Text('Saving marks sets this submission to graded. Parents are notified of the mark.', style: EmType.caption.copyWith(color: EmColors.textSecondary))),
      ],
    ];
  }
}
