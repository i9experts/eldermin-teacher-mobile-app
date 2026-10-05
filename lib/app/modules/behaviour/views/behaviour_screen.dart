import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/behaviour_controller.dart';
import 'widgets/behaviour_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Behaviour & Tarbiyah', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      floatingActionButton: Obx(() => c.canView && c.canLog && c.classes.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('beh_new_fab'),
              backgroundColor: AppColors.primaryColor,
              onPressed: () => Get.toNamed(Routes.behaviourNew),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const CustomText(text: 'Log behaviour', color: Colors.white, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      header: [
        const ScreenHeader(title: 'Behaviour', caption: 'Merits, concerns and notes'),
        if (c.canView) ...[
          const ParentVisibleNote(text: 'Everything recorded here is visible to the student\'s parents in their app.'),
          const SizedBox(height: 12),
        ],
        if (state.hasData) ...[
          SegmentedControl(
            options: ['My entries ($myCount)', 'My classes ($total)'],
            selectedIndex: scope == BehaviourScope.mine ? 0 : 1,
            onChanged: (i) => c.setScope(i == 0 ? BehaviourScope.mine : BehaviourScope.classes),
          ),
          const SizedBox(height: 10),
          if (classes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilterChipsRow(chips: [
                ('All classes', 0, filter < 0, () => c.setClassFilter(-1), 'cls_all'),
                for (var i = 0; i < classes.length; i++) (classes[i].label, 0, filter == i, () => c.setClassFilter(i), 'cls_$i'),
              ]),
            ),
          TextField(
            key: const Key('beh_search'),
            controller: search,
            onChanged: (v) => c.query.value = v,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by student or title',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
      builder: (_) {
        if (visible.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 20),
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
