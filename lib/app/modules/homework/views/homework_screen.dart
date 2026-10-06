import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/homework/homework_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/homework_controller.dart';
import 'widgets/homework_widgets.dart';

/// My homework (`/homework`): my assignments with status filters, sort and "show more" (client-side paging).
class HomeworkScreen extends GetView<HomeworkController> {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Homework', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      floatingActionButton: Obx(() => controller.canView && controller.state.value.status != SectionStatus.forbidden
          ? FloatingActionButton.extended(
              key: const Key('hw_new_fab'),
              backgroundColor: AppColors.primaryColor,
              onPressed: () => Get.toNamed(Routes.homeworkNew),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const CustomText(text: 'New homework', color: Colors.white, fontWeight: FontWeight.w700),
            )
          : const SizedBox.shrink()),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    // reactive reads inside the Obx
    final state = c.state.value;
    final filter = c.filter.value;
    final newest = c.newestFirst.value;
    final visible = c.visible;
    final total = c.filtered.length;
    final hasMore = c.hasMore;
    final today = c.today;
    final all = c.items.length;
    return ScreenStateView<List<Assignment>>(
      state: c.canView ? state : const SectionState<List<Assignment>>.forbidden(),
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.menu_book_outlined,
      emptyTitle: 'No homework yet',
      emptySubtitle: 'Assignments you create will appear here. Tap "New homework" to set one.',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      header: [
        ScreenHeader(title: 'Homework', caption: state.hasData ? '$all ${all == 1 ? 'assignment' : 'assignments'} · mine' : 'Your assignments'),
        if (state.hasData) ...[
          FilterChipsRow(chips: [
            for (final f in HomeworkFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('hw_sort'),
              onPressed: c.toggleSort,
              icon: Icon(newest ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16),
              label: CustomText(text: newest ? 'Latest due first' : 'Earliest due first', color: AppColors.primaryColor, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: AppEmptyView(key: const Key('hw_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No ${filter.label.toLowerCase()} homework'),
            ),
          ];
        }
        return [
          for (final a in visible) HomeworkTile(assignment: a, today: today, onTap: () => Get.toNamed(Routes.homeworkDetailOf(a.id))),
          if (hasMore)
            Center(
              child: TextButton(
                key: const Key('hw_show_more'),
                onPressed: c.showMore,
                child: CustomText(text: 'Show more (${total - visible.length} left)', color: AppColors.primaryColor, fontWeight: FontWeight.w800),
              ),
            ),
        ];
      },
    );
  }
}
