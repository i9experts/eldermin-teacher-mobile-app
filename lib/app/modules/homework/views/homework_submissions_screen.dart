import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/submissions_controller.dart';
import 'widgets/homework_widgets.dart';

/// Submissions of one assignment (`/homework/:id/submissions`): the whole class roster with who handed in, who is late, who still has
/// to be graded and who has not handed in at all.
class HomeworkSubmissionsScreen extends GetView<SubmissionsController> {
  const HomeworkSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Submissions', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state.value;
    final filter = c.filter.value;
    final visible = c.visible;
    final a = c.assignment;
    return ScreenStateView<SubmissionsResult>(
      state: state,
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.inbox_outlined,
      emptyTitle: 'No submissions yet',
      emptySubtitle: 'Once the homework is assigned, every student of the class appears here.',
      header: [
        ScreenHeader(title: a?.title.isNotEmpty == true ? a!.title : 'Submissions', caption: a == null ? null : [a.subject, a.classLabel].where((e) => e.isNotEmpty).join(' · ')),
      ],
      builder: (res) {
        if (res.submissions.isEmpty) {
          return [
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: AppEmptyView(key: Key('subs_none'), icon: Icons.inbox_outlined, title: 'No students on this list', subtitle: 'The server has no student rows for this assignment (no active students matched the class when it was assigned).'),
            ),
          ];
        }
        return [
          StatsRow(items: [
            ('${c.countFor(SubmissionFilter.toGrade)}', 'To grade', null),
            ('${c.countFor(SubmissionFilter.graded)}', 'Graded', null),
            ('${c.countFor(SubmissionFilter.notHandedIn)}', 'Not handed in', null),
          ]),
          const SizedBox(height: 10),
          FilterChipsRow(chips: [
            for (final f in SubmissionFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name),
          ]),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 20), child: AppEmptyView(key: const Key('subs_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'Nobody in "${filter.label}"'))
          else
            for (final s in visible)
              SubmissionTile(
                submission: s,
                onTap: () {
                  if (c.canGrade(s)) {
                    Get.toNamed(Routes.homeworkGradeOf(c.assignmentId, s.id));
                  } else {
                    ScaffoldMessenger.of(Get.context!)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text('${s.studentName.isEmpty ? 'This student' : s.studentName} has not handed anything in yet.'), behavior: SnackBarBehavior.floating));
                  }
                },
              ),
        ];
      },
    );
  }
}
