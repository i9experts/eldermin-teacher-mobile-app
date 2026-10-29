import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/toast_util.dart';
import '../controllers/homework_detail_controller.dart';
import 'widgets/homework_widgets.dart';
import '../../../../core/design/design.dart';
import '../../../common/write_access.dart';

/// One assignment (`/homework/:id`): details, attachments, and the actions that make sense for its state.
class HomeworkDetailScreen extends GetView<HomeworkDetailController> {
  const HomeworkDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Homework'),
      body: Obx(() {
        final c = controller;
        final state = c.state;
        final busy = c.busy.value;
        final opening = c.openingKey.value;
        return ScreenStateView<Assignment>(
          state: state,
          onRefresh: c.reload,
          onRetry: c.load,
          emptyTitle: 'Not found',
          builder: (a) => _content(context, a, busy, opening),
        );
      }),
    );
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  List<Widget> _content(BuildContext context, Assignment a, bool busy, String? opening) {
    final c = controller;
    final today = c.today;
    final due = a.dueDay;
    final body = EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5);
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(a.title, key: const Key('hw_title'), style: EmType.title.copyWith(color: EmColors.ink))),
        const SizedBox(width: EmSpacing.s8),
        PhaseTag(assignment: a, today: today),
      ]),
      const SizedBox(height: EmSpacing.s4),
      Text([a.subject, a.classLabel, a.typeLabel].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
      const SizedBox(height: EmSpacing.block),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoLine(icon: Icons.event_rounded, text: due == null ? 'No due date' : '${dueText(a, today)} (${fullDay(due)})'),
          InfoLine(icon: Icons.grade_outlined, text: 'Total ${markText(a.totalMarks)} marks · pass at ${markText(a.passingMarks)}'),
          if (!a.isDraft) InfoLine(icon: Icons.inbox_rounded, text: '${a.submissionsCount} handed in'),
          if (!a.isDraft && a.avgScore > 0) InfoLine(icon: Icons.analytics_outlined, text: 'Average mark ${markText(a.avgScore)}'),
        ]),
      ),
      if (a.description.isNotEmpty) ...[const SubHeading('Description'), AppCard(child: Text(a.description, style: body))],
      if (a.instructions.isNotEmpty) ...[const SubHeading('Instructions'), AppCard(child: Text(a.instructions, style: body))],
      if (a.attachmentKeys.isNotEmpty) ...[
        const SubHeading('Attachments'),
        for (var i = 0; i < a.attachmentKeys.length; i++)
          AttachmentLink(
            key: ValueKey('hw_att_$i'),
            label: attachmentLabel(a.attachmentKeys[i], i),
            busy: opening == a.attachmentKeys[i],
            onTap: () async {
              final r = await c.openAttachment(a.attachmentKeys[i]);
              if (r is DetailFailed && context.mounted) _snack(context, r.failure.message);
            },
          ),
      ],
      const SizedBox(height: EmSpacing.block),
      if (a.isDraft && canWriteHomework)
        EmPrimaryButton(key: const Key('hw_assign'), icon: Icons.send_rounded, label: 'Assign to class', onPressed: busy ? null : () => _assign(context, a))
      else if (!a.isDraft)
        EmPrimaryButton(key: const Key('hw_view_submissions'), icon: Icons.inbox_rounded, label: 'Submissions and grading', onPressed: () => Get.toNamed(Routes.homeworkSubmissionsOf(a.id))),
      const SizedBox(height: EmSpacing.s8),
      if (canWriteHomework) EmSecondaryButton(key: const Key('hw_edit'), expand: true, icon: Icons.edit_outlined, label: 'Edit', onPressed: busy ? null : () => Get.toNamed(Routes.homeworkNew, arguments: a)),
      if (!a.isDraft)
        Padding(
          padding: const EdgeInsets.only(top: EmSpacing.s8),
          child: Text("Class, subject and total marks can't be changed after the homework is assigned.", style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ),
      const SizedBox(height: EmSpacing.s8),
      if (canWriteHomework) Center(child: EmTextAction(key: const Key('hw_delete'), destructive: true, icon: Icons.delete_outline_rounded, label: 'Delete', onPressed: busy ? null : () => _delete(context, a))),
    ];
  }

  Future<void> _assign(BuildContext context, Assignment a) async {
    final ok = await ConfirmDialog.show(
      title: 'Assign to ${a.classLabel}?',
      message: 'The guardians of the students in this class will be notified, and every student appears in the submissions list.',
      confirmLabel: 'Assign',
    );
    if (!ok) return;
    final r = await controller.assign();
    if (!context.mounted) return;
    if (r is DetailFailed) {
      _snack(context, r.failure.message);
    } else if (r is DetailOk) {
      ToastUtil.showToast('Assigned to ${a.classLabel}');
    }
  }

  Future<void> _delete(BuildContext context, Assignment a) async {
    final ok = await ConfirmDialog.show(
      title: 'Delete this homework?',
      message: a.isDraft
          ? '"${a.title}" will be deleted. This cannot be undone.'
          : '"${a.title}" will be deleted together with every submission and grade for it (${a.submissionsCount} handed in). This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final r = await controller.delete();
    if (!context.mounted) return;
    if (r is DetailFailed) {
      _snack(context, r.failure.message);
    } else if (r is DetailOk) {
      ToastUtil.showToast('Homework deleted');
      Get.back();
    }
  }
}
