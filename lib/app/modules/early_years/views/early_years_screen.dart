import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/early_years/ece_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../homework/views/widgets/homework_widgets.dart';
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

  /// Opens the child. Wired by the detail screens (EY-T2); until then a tile is not tappable.
  void Function(EceChild)? get onOpenChild => null;

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
      emptyTitle: classes.isEmpty ? "You aren't assigned to any class yet" : 'No Early Years children in your classes',
      emptySubtitle: classes.isEmpty
          ? 'Early Years is shown for the children of your classes. Ask your school admin to assign you to a class.'
          : 'A child appears here when their programme is set to Early Years and they are in one of your classes.',
      padding: EmSpacing.listPadding,
      header: [
        const EmCaptionLine('Observations and portfolios'),
        if (state.hasData) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: EmSpacing.row),
            child: Text('$total ${total == 1 ? 'child' : 'children'} in your classes', key: const Key('ey_count'), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ),
          if (classes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.row),
              child: FilterChipsRow(chips: [
                ('All classes', -1, filter < 0, () => c.setClassFilter(-1), 'cls_all'),
                for (var i = 0; i < classes.length; i++) (classes[i].label, -1, filter == i, () => c.setClassFilter(i), 'cls_$i'),
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
              child: AppEmptyView(
                key: const Key('ey_filter_empty'),
                icon: Icons.filter_alt_off_outlined,
                title: q.isNotEmpty ? 'Nothing matches "$q"' : 'No children in this class',
              ),
            ),
          ];
        }
        final open = onOpenChild;
        return [
          for (final k in visible) EceChildTile(child: k, onTap: open == null ? null : () => open(k)),
        ];
      },
    );
  }
}
