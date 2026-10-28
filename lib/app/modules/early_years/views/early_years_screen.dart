import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../controllers/early_years_controller.dart';
import 'widgets/early_years_widgets.dart';

/// Early Years (`/early-years`): the Early Years children of MY classes. Children of other classes never appear.
class EarlyYearsScreen extends StatefulWidget {
  const EarlyYearsScreen({super.key});

  @override
  State<EarlyYearsScreen> createState() => _EarlyYearsScreenState();
}

class _EarlyYearsScreenState extends State<EarlyYearsScreen> {
  final search = TextEditingController();
  EarlyYearsController get c => Get.find<EarlyYearsController>();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Early Years'),
      body: Obx(_body),
    );
  }

  void _openChild(EceChild k) => Get.toNamed(Routes.earlyYearsChildOf(k.id), arguments: k);

  Widget _body() {
    final state = c.state.value;
    final filter = c.classFilter.value;
    final visible = c.visible;
    final classes = c.classes;
    final q = c.query.value;
    final total = c.all.length;
    return ScreenStateView<List<EceChild>>(
      state: state,
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: classes.isEmpty ? Icons.school_outlined : Icons.child_care_rounded,
      emptyTitle: classes.isEmpty ? "You aren't assigned to a class yet" : 'No Early Years children in your classes',
      emptySubtitle: classes.isEmpty
          ? 'Early Years shows the children of the classes assigned to you. Ask your school admin to assign you to a class, then pull down to refresh.'
          : 'Only children in classes assigned to you are shown here. A child appears when their programme is set to Early Years and they are in one of your classes. Pull down to refresh.',
      padding: EmSpacing.listPadding,
      header: [
        const EmCaptionLine('Observations and portfolios'),
        if (state.hasData) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: EmSpacing.row),
            child: Text('$total ${total == 1 ? 'child' : 'children'} in your classes', key: const Key('ey_count'), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ),
          const EmInfoBanner(key: Key('ey_scope_note'), tone: EmTone.neutral, icon: Icons.groups_rounded, text: 'Showing only the children in the classes assigned to you.'),
          const SizedBox(height: EmSpacing.row),
          if (classes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.row),
              child: Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
                EmChip(key: const Key('cls_all'), label: 'All classes', selected: filter < 0, onTap: () => c.setClassFilter(-1)),
                for (var i = 0; i < classes.length; i++) EmChip(key: Key('cls_$i'), label: classes[i].label, selected: filter == i, onTap: () => c.setClassFilter(i)),
              ]),
            ),
          EmSearchPill(fieldKey: const Key('ey_search'), controller: search, hint: 'Search by name or student ID', onChanged: (v) => c.query.value = v),
          const SizedBox(height: EmSpacing.row),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: EmSpacing.s24),
              child: EmEmptyState(
                key: const Key('ey_filter_empty'),
                scroll: false,
                icon: Icons.filter_alt_off_outlined,
                title: q.isNotEmpty ? 'Nothing matches "$q"' : 'No children in this class',
              ),
            ),
          ];
        }
        return [
          for (final k in visible) EceChildTile(child: k, onTap: () => _openChild(k)),
        ];
      },
    );
  }
}
