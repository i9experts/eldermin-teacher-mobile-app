import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/curriculum_controller.dart';

/// Curriculum (`/curriculum`): the learning outcomes (SLOs) framework for my grades. Read-only: creating, editing and adding SLOs are
/// coordinator actions.
class CurriculumScreen extends GetView<CurriculumController> {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Curriculum', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final c = controller;
        final state = c.state.value;
        final scope = c.scope.value;
        final visible = c.filtered;
        return ScreenStateView<List<Curriculum>>(
          state: c.canView ? state : const SectionState<List<Curriculum>>.forbidden(),
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          emptyIcon: Icons.account_tree_outlined,
          emptyTitle: 'No curriculum for your grades yet',
          emptySubtitle: 'Your school publishes a curriculum per grade and subject. Once one exists for a grade you teach, it appears here.',
          header: [
            ScreenHeader(title: 'Curriculum', caption: state.hasData ? '${visible.length} for your classes' : 'Learning outcomes by grade'),
            if (state.hasData) ...[
              FilterChipsRow(chips: [for (final s in CurriculumScope.values) (s.label, c.countFor(s), s == scope, () => c.setScope(s), s.name)]),
              const SizedBox(height: 10),
            ],
          ],
          builder: (_) {
            if (visible.isEmpty) {
              return [const Padding(padding: EdgeInsets.only(top: 24), child: AppEmptyView(key: Key('cur_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No curriculum for your subjects', subtitle: 'Try "All my grades".'))];
            }
            return [for (final k in visible) _tile(k, c.forMySubject(k))];
          },
        );
      }),
    );
  }

  Widget _tile(Curriculum k, bool mine) => AppCard(
        key: ValueKey('cur_${k.id}'),
        onTap: () => Get.toNamed(Routes.curriculumDetailOf(k.id)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: CustomText(text: k.name.isEmpty ? k.subjectName : k.name, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (mine) const AppTag('YOUR SUBJECT', style: TagStyle.info),
          ]),
          const SizedBox(height: 3),
          CustomText(text: [k.gradeLevel, k.subjectName, if (k.academicYearLabel.isNotEmpty) k.academicYearLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
          CustomText(text: '${k.slos.length} learning ${k.slos.length == 1 ? 'outcome' : 'outcomes'}${k.framework.isEmpty ? '' : ' · ${k.framework}'}', color: AppColors.muted, fontSize: 12),
        ]),
      );
}
