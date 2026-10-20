import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../home/models/section_state.dart';
import '../controllers/behaviour_controller.dart';
import 'widgets/behaviour_widgets.dart';
import '../../../../core/design/design.dart';

/// Behaviour & Tarbiyah (`/behaviour`): what I logged and what is recorded for my classes. Records of other classes never appear.
class BehaviourScreen extends StatefulWidget {
  const BehaviourScreen({super.key});

  @override
  State<BehaviourScreen> createState() => _BehaviourScreenState();
}

class _BehaviourScreenState extends State<BehaviourScreen> {
  final search = TextEditingController();
  BehaviourController get c => Get.find<BehaviourController>();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Behaviour & Tarbiyah'),
      floatingActionButton: Obx(() => c.canView && c.canLog && c.classes.isNotEmpty && c.state.value.status != SectionStatus.forbidden
          ? FloatingActionButton.extended(
              key: const Key('beh_new_fab'),
              onPressed: () => Get.toNamed(Routes.behaviourNew),
              icon: const Icon(Icons.add_rounded),
              label: Text('Log behaviour', style: EmType.label.copyWith(color: EmColors.onPrimary)),
            )
          : const SizedBox.shrink()),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final state = c.state.value;
    final scope = c.scope.value;
    final filter = c.classFilter.value;
    final visible = c.visible;
    final classes = c.classes;
    final myCount = c.countMine();
    final total = c.all.length;
    final q = c.query.value;
    final myId = c.myId, myName = c.myName;
    return ScreenStateView<List<BehaviourRecord>>(
      state: state,
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: classes.isEmpty ? Icons.school_outlined : Icons.emoji_events_outlined,
      emptyTitle: classes.isEmpty ? "You aren't assigned to any class yet" : 'No behaviour recorded yet',
      emptySubtitle: classes.isEmpty ? 'Behaviour is logged for the students of your classes. Ask your school admin to assign you to a class.' : 'Tap "Log behaviour" to record a merit, a concern or a note.',
      padding: EmSpacing.listPaddingFab,
      header: [
        const EmCaptionLine('Merits, concerns and notes'),
        if (c.canView) const ParentVisibleNote(text: 'Everything recorded here is visible to the student\'s parents in their app.'),
        if (state.hasData) ...[
          EmSegmentedTabs<BehaviourScope>(
            segments: [EmSegment(BehaviourScope.mine, 'My entries ($myCount)'), EmSegment(BehaviourScope.classes, 'My classes ($total)')],
            selected: scope == BehaviourScope.mine ? BehaviourScope.mine : BehaviourScope.classes,
            onChanged: c.setScope,
          ),
          const SizedBox(height: EmSpacing.row),
          if (classes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: EmSpacing.row),
              child: FilterChipsRow(chips: [
                ('All classes', -1, filter < 0, () => c.setClassFilter(-1), 'cls_all'),
                for (var i = 0; i < classes.length; i++) (classes[i].label, -1, filter == i, () => c.setClassFilter(i), 'cls_$i'),
              ]),
            ),
          EmSearchPill(fieldKey: const Key('beh_search'), controller: search, hint: 'Search by student or title', onChanged: (v) => c.query.value = v),
          const SizedBox(height: EmSpacing.row),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: EmSpacing.s24),
              child: AppEmptyView(
                key: const Key('beh_filter_empty'),
                icon: Icons.filter_alt_off_outlined,
                title: q.isNotEmpty ? 'Nothing matches "$q"' : (scope == BehaviourScope.mine ? "You haven't logged anything yet" : 'No records for this class'),
              ),
            ),
          ];
        }
        return [
          for (final r in visible)
            BehaviourTile(record: r, mine: r.isMine(userId: myId, userName: myName), onTap: () => Get.toNamed(Routes.behaviourStudentOf(r.studentId))),
        ];
      },
    );
  }
}
