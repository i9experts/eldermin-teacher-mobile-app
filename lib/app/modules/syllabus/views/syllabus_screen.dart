import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/syllabus_controller.dart';
import 'widgets/syllabus_widgets.dart';

/// My syllabi (`/syllabus`): coverage progress per subject and class, a behind-schedule tag, and the weekly planner entry.
class SyllabusScreen extends GetView<SyllabusController> {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Syllabus', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state.value;
    final filter = c.filter.value;
    final visible = c.filtered;
    final all = c.items.length;
    return ScreenStateView<List<Syllabus>>(
      state: c.canView ? state : const SectionState<List<Syllabus>>.forbidden(),
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: Icons.checklist_rounded,
      emptyTitle: 'No syllabus for your classes yet',
      emptySubtitle: 'Your school adds a syllabus per subject and class. Once one is assigned to you or to a class you teach, it appears here.',
      header: [
        ScreenHeader(title: 'Syllabus', caption: state.hasData ? '$all ${all == 1 ? 'syllabus' : 'syllabi'} · mine' : 'Coverage tracking'),
        if (c.canView && state.status != SectionStatus.forbidden)
          AppCard(
            key: const Key('syl_planner_card'),
            onTap: () => Get.toNamed(Routes.syllabusWeeklyPlanner),
            child: const Row(children: [
              Icon(Icons.date_range_rounded, color: AppColors.primaryColor),
              SizedBox(width: 10),
              Expanded(child: CustomText(text: 'Weekly planner', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ),
        if (state.hasData)
          FilterChipsRow(chips: [
            for (final f in SyllabusFilter.values) (f.label, c.countFor(f), f == filter, () => c.setFilter(f), f.name),
          ]),
        if (state.hasData) const SizedBox(height: 10),
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [Padding(padding: const EdgeInsets.only(top: 24), child: AppEmptyView(key: const Key('syl_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No ${filter.label.toLowerCase()} syllabus'))];
        }
        return [for (final s in visible) SyllabusTile(syllabus: s, assignedToMe: c.assignedToMe(s), onTap: () => Get.toNamed(Routes.syllabusDetailOf(s.id)))];
      },
    );
  }
}
