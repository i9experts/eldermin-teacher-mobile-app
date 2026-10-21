import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/reference_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/curriculum_controller.dart';
import '../../../../core/design/design.dart';

/// Curriculum (`/curriculum`): the learning outcomes (SLOs) framework for my grades. Read-only: creating, editing and adding SLOs are
/// coordinator actions.
class CurriculumScreen extends GetView<CurriculumController> {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Curriculum'),
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
            EmCaptionLine(state.hasData ? '${visible.length} for your classes' : 'Learning outcomes by grade'),
            if (state.hasData) ...[
              FilterChipsRow(chips: [for (final s in CurriculumScope.values) (s.label, c.countFor(s), s == scope, () => c.setScope(s), s.name)]),
              const SizedBox(height: EmSpacing.row),
            ],
          ],
          builder: (_) {
            if (visible.isEmpty) {
              return [const Padding(padding: EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: Key('cur_filter_empty'), icon: Icons.filter_alt_off_outlined, title: 'No curriculum for your subjects', subtitle: 'Try "All my grades".'))];
            }
            return [for (final k in visible) _tile(k, c.forMySubject(k))];
          },
        );
      }),
    );
  }

  Widget _tile(Curriculum k, bool mine) {
    final quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400);
    return AppCard(
      key: ValueKey('cur_${k.id}'),
      onTap: () => Get.toNamed(Routes.curriculumDetailOf(k.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k.name.isEmpty ? k.subjectName : k.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          if (mine) ...[const SizedBox(width: EmSpacing.s8), const AppTag('YOUR SUBJECT', style: EmTone.info)],
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text([k.gradeLevel, k.subjectName, if (k.academicYearLabel.isNotEmpty) k.academicYearLabel].where((e) => e.isNotEmpty).join(' · '), style: quiet),
        Text('${k.slos.length} learning ${k.slos.length == 1 ? 'outcome' : 'outcomes'}${k.framework.isEmpty ? '' : ' · ${k.framework}'}', style: quiet),
      ]),
    );
  }
}
