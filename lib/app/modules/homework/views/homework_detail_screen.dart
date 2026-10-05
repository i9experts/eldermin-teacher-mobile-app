import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/toast_util.dart';
import '../controllers/homework_detail_controller.dart';
import 'widgets/homework_widgets.dart';

/// One assignment (`/homework/:id`): details, attachments, and the actions that make sense for its state.
class HomeworkDetailScreen extends GetView<HomeworkDetailController> {
  const HomeworkDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Homework', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  List<Widget> _content(BuildContext context, Assignment a, bool busy, String? opening) {
    final c = controller;
    final today = c.today;
    final due = a.dueDay;
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: CustomText(text: a.title, key: const Key('hw_title'), fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor, height: 1.2)),
        const SizedBox(width: 8),
        PhaseTag(assignment: a, today: today),
      ]),
      const SizedBox(height: 4),
      CustomText(text: [a.subject, a.classLabel, a.typeLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoLine(icon: Icons.event_rounded, text: due == null ? 'No due date' : '${dueText(a, today)} (${fullDay(due)})'),
          InfoLine(icon: Icons.grade_outlined, text: 'Total ${markText(a.totalMarks)} marks · pass at ${markText(a.passingMarks)}'),
          if (!a.isDraft) InfoLine(icon: Icons.inbox_rounded, text: '${a.submissionsCount} handed in'),
          if (!a.isDraft && a.avgScore > 0) InfoLine(icon: Icons.analytics_outlined, text: 'Average mark ${markText(a.avgScore)}'),
        ]),
      ),
      if (a.description.isNotEmpty) ...[const SubHeading('Description'), AppCard(child: CustomText(text: a.description, fontSize: 12.5, height: 1.4))],
      if (a.instructions.isNotEmpty) ...[const SubHeading('Instructions'), AppCard(child: CustomText(text: a.instructions, fontSize: 12.5, height: 1.4))],
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
      const SizedBox(height: 14),
      if (a.isDraft) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('hw_assign'),
            onPressed: busy ? null : () => _assign(context, a),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const CustomText(text: 'Assign to class', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
      ] else ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('hw_view_submissions'),
            onPressed: () => Get.toNamed(Routes.homeworkSubmissionsOf(a.id)),
            icon: const Icon(Icons.inbox_rounded, size: 18),
            label: const CustomText(text: 'Submissions and grading', color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
      ],
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('hw_edit'),
          onPressed: busy ? null : () => Get.toNamed(Routes.homeworkNew, arguments: a),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const CustomText(text: 'Edit', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
        ),
      ),
      if (!a.isDraft)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CustomText(text: "Class, subject and total marks can't be changed after the homework is assigned.", color: AppColors.muted, fontSize: 11),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          key: const Key('hw_delete'),
          onPressed: busy ? null : () => _delete(context, a),
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.redText),
          label: const CustomText(text: 'Delete', color: AppColors.redText, fontWeight: FontWeight.w700),
        ),
      ),
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
