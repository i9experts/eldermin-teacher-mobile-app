import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/lesson_plan_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/lesson_plans_controller.dart';
import 'widgets/lesson_plan_widgets.dart';

/// My lesson plans (`/lesson-plans`): status chips (with counts), rejection reasons on rejected plans, create and "Upload & parse".
class LessonPlansScreen extends GetView<LessonPlansController> {
  const LessonPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CustomText(text: 'Lesson plans', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        actions: [
          Obx(() => controller.canView && controller.state.value.status != SectionStatus.forbidden
              ? IconButton(
                  key: const Key('lp_upload_action'),
                  tooltip: 'Upload & parse',
                  onPressed: () => Get.toNamed(Routes.lessonPlanUpload),
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                )
              : const SizedBox.shrink()),
        ],
      ),
      floatingActionButton: Obx(() => controller.canView && controller.state.value.status != SectionStatus.forbidden
          ? FloatingActionButton.extended(
              key: const Key('lp_new_fab'),
              backgroundColor: AppColors.primaryColor,
              onPressed: () => Get.toNamed(Routes.lessonPlanNew),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const CustomText(text: 'New plan', color: Colors.white, fontWeight: FontWeight.w700),
            )
          : const SizedBox.shrink()),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state.value;
    final filter = c.filter.value;
    final visible = c.filtered;
    final all = c.items.length;
    return ScreenStateView<List<LessonPlanRecord>>(
      state: c.canView ? state : const SectionState<List<LessonPlanRecord>>.forbidden(),
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.edit_note_rounded,
      emptyTitle: 'No lesson plans yet',
      emptySubtitle: 'Plans you create will appear here. Tap "New plan", or "Upload & parse" to start from a document.',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      header: [
        ScreenHeader(title: 'Lesson plans', caption: state.hasData ? '$all ${all == 1 ? 'plan' : 'plans'} · mine' : 'Your plans'),
        if (state.hasData) ...[
          FilterChipsRow(chips: [
            for (final f in LessonPlanFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name),
          ]),
          const SizedBox(height: 10),
          if (c.maybeTruncated)
            const NoteBox(
              boxKey: Key('lp_truncated'),
              icon: Icons.info_outline_rounded,
              title: 'Showing your 100 newest plans',
              body: 'The server returns at most 100 plans per request, so older ones may not be listed here.',
              fg: AppColors.amberText,
              bg: AppColors.amberBg,
            ),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: AppEmptyView(key: const Key('lp_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No ${filter.label.toLowerCase()} plans'),
            ),
          ];
        }
        return [for (final p in visible) LessonPlanTile(plan: p, onTap: () => Get.toNamed(Routes.lessonPlanDetailOf(p.id)))];
      },
    );
  }
}
