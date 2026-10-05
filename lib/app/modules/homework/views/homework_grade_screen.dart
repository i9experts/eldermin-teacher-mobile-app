import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../controllers/submissions_controller.dart';
import 'widgets/homework_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Grade submission', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
    return [
      CustomText(text: s.studentName.isEmpty ? 'Student' : s.studentName, key: const Key('grade_student'), fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
      const SizedBox(height: 6),
      SubmissionTags(s: s),
      if (s.submittedAt != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: 'Handed in ${instantText(s.submittedAt!)}', color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 14),
      const SubHeading('Answer'),
      AppCard(
        child: s.textResponse.isEmpty
            ? const CustomText(key: Key('grade_no_text'), text: 'No written answer.', color: AppColors.muted, fontSize: 12)
            : CustomText(key: const Key('grade_text'), text: s.textResponse, fontSize: 12.5, height: 1.4),
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
              if (f != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message), behavior: SnackBarBehavior.floating));
            },
          ),
      ],
      const SubHeading('Marks'),
      if (!gradable)
        const AppCard(child: CustomText(key: Key('grade_not_gradable'), text: 'Nothing has been handed in yet, so there is nothing to grade.', color: AppColors.muted, fontSize: 12.5))
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('grade_save'),
            onPressed: saving ? null : () => _save(s),
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : CustomText(text: s.isGraded ? 'Update marks' : 'Save marks', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 8), child: CustomText(text: "Saving marks marks this submission as graded. Parents are notified of the mark.", color: AppColors.muted, fontSize: 11)),
      ],
    ];
  }
}
