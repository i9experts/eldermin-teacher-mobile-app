import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../controllers/syllabus_controller.dart';
import '../controllers/weekly_planner_controller.dart';
import 'widgets/syllabus_widgets.dart';

/// Weekly planner (`/syllabus/weekly-planner`): the sub-topics planned for a term week, per syllabus / class, tickable. The server answers
/// the CURRENT week only; the arrows move through the other weeks using the planned weeks stored on each syllabus.
class SyllabusWeeklyPlannerScreen extends StatefulWidget {
  const SyllabusWeeklyPlannerScreen({super.key});

  @override
  State<SyllabusWeeklyPlannerScreen> createState() => _PlannerState();
}

class _PlannerState extends State<SyllabusWeeklyPlannerScreen> with WidgetsBindingObserver {
  WeeklyPlannerController get c => Get.find<WeeklyPlannerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.refreshIfStale();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Future<void> _tick(Future<MarkResult> f) async {
    final r = await f;
    if (r is MarkFailed && mounted) _snack(r.failure.message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Weekly planner', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(() {
        final state = c.state.value;
        final cards = c.cards;
        final label = c.weekLabel;
        final off = c.offset.value;
        final pending = c.syllabi.pending.toSet();
        return ScreenStateView<List<PlannerEntry>>(
          state: state,
          onRefresh: c.reload,
          onRetry: () => c.load(force: true),
          emptyIcon: Icons.event_available_rounded,
          emptyTitle: 'Nothing planned for this week',
          emptySubtitle: 'The planner lists sub-topics scheduled for the current term week in your active or approved syllabi. Ask your school if a pacing guide has been generated.',
          header: [
            if (state.hasData) _weekBar(label, off),
          ],
          builder: (_) {
            if (cards.isEmpty) {
              return [const AppEmptyView(key: Key('planner_week_empty'), icon: Icons.event_busy_rounded, title: 'No syllabus has a week here')];
            }
            return [for (final k in cards) _card(k, off, pending)];
          },
        );
      }),
    );
  }

  Widget _weekBar(String label, int off) {
    final cards = c.cards;
    final weeks = {for (final k in cards) k.week};
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        IconButton(key: const Key('planner_prev'), onPressed: c.canGoEarlier ? c.earlier : null, icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Column(children: [
            CustomText(key: const Key('planner_label'), text: label, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 16),
            CustomText(text: weeks.isEmpty ? '' : (weeks.length == 1 ? 'Week ${weeks.first}' : 'Weeks ${(weeks.toList()..sort()).join(', ')}'), color: AppColors.muted, fontSize: 11),
          ]),
        ),
        IconButton(key: const Key('planner_next'), onPressed: c.canGoLater ? c.later : null, icon: const Icon(Icons.chevron_right_rounded)),
        if (off != 0) TextButton(key: const Key('planner_today'), onPressed: c.thisWeek, child: const CustomText(text: 'This week', color: AppColors.primaryColor, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _card(PlannerCard k, int off, Set<String> pending) {
    final e = k.entry;
    final s = k.syllabus;
    return AppCard(
      key: ValueKey('planner_${e.syllabusId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: '${e.subjectName} · ${e.classLabel}', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13.5)),
          AppTag('WEEK ${k.week}', style: TagStyle.info),
        ]),
        const SizedBox(height: 6),
        if (k.rows.isEmpty)
          CustomText(key: ValueKey('planner_none_${e.syllabusId}'), text: s == null && off != 0 ? 'Not available for this week.' : 'Nothing planned for this week.', color: AppColors.muted, fontSize: 12),
        for (final r in k.rows) _row(e.syllabusId, r, pending, ValueKey('prow_${e.syllabusId}_${r.unit?.no}_${r.topic?.no}_${r.sub.no}')),
        if (k.earlier.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(top: 10, bottom: 2), child: CustomText(text: 'PLANNED FOR EARLIER WEEKS, NOT COVERED YET', color: AppColors.amberText, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          for (final r in k.earlier) _row(e.syllabusId, r, pending, ValueKey('erow_${e.syllabusId}_${r.unit?.no}_${r.topic?.no}_${r.sub.no}')),
        ],
      ]),
    );
  }

  Widget _row(String sid, PlannerRow r, Set<String> pending, Key key) {
    final u = r.unit?.no ?? 0, t = r.topic?.no ?? 0;
    return Row(key: key, children: [
      CoverageBox(
        covered: r.sub.isCovered,
        busy: pending.contains('s:$sid:$u:$t:${r.sub.no}'),
        onTap: () => _tick(c.syllabi.markSubTopic(sid, u, t, r.sub.no, !r.sub.isCovered)),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(text: r.sub.name, fontSize: 12.5, color: AppColors.black, fontWeight: FontWeight.w600),
          CustomText(text: [if (r.topic != null && r.topic!.name.isNotEmpty) r.topic!.name, if (r.unit != null && r.unit!.name.isNotEmpty) r.unit!.name].join(' · '), fontSize: 10.5, color: AppColors.muted),
        ]),
      ),
      if (r.sub.plannedWeek != null) AppTag('W${r.sub.plannedWeek}', style: TagStyle.neutral),
    ]);
  }
}
