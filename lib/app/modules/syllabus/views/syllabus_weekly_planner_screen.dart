import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../controllers/syllabus_controller.dart';
import '../controllers/weekly_planner_controller.dart';
import 'widgets/syllabus_widgets.dart';
import '../../../../core/design/design.dart';

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
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _tick(Future<MarkResult> f) async {
    final r = await f;
    if (r is MarkFailed && mounted) _snack(r.failure.message);
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Weekly planner'),
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
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          EmIconCircleButton(key: const Key('planner_prev'), icon: Icons.chevron_left_rounded, semanticLabel: 'Earlier week', tooltip: 'Earlier week', elevated: false, onTap: c.canGoEarlier ? c.earlier : null),
          Expanded(
            child: Column(children: [
              Text(label, key: const Key('planner_label'), textAlign: TextAlign.center, style: EmType.heading.copyWith(color: EmColors.ink)),
              Text(weeks.isEmpty ? '' : (weeks.length == 1 ? 'Week ${weeks.first}' : 'Weeks ${(weeks.toList()..sort()).join(', ')}'), textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ]),
          ),
          EmIconCircleButton(key: const Key('planner_next'), icon: Icons.chevron_right_rounded, semanticLabel: 'Later week', tooltip: 'Later week', elevated: false, onTap: c.canGoLater ? c.later : null),
        ]),
        if (off != 0) Center(child: TextButton(key: const Key('planner_today'), onPressed: c.thisWeek, child: Text('This week', style: EmType.label.copyWith(color: EmColors.primary)))),
      ]),
    );
  }

  Widget _card(PlannerCard k, int off, Set<String> pending) {
    final e = k.entry;
    final s = k.syllabus;
    return AppCard(
      key: ValueKey('planner_${e.syllabusId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${e.subjectName} · ${e.classLabel}', style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          AppTag('WEEK ${k.week}', style: EmTone.info),
        ]),
        const SizedBox(height: EmSpacing.s8),
        if (k.rows.isEmpty) Text(s == null && off != 0 ? 'Not available for this week.' : 'Nothing planned for this week.', key: ValueKey('planner_none_${e.syllabusId}'), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
        for (final r in k.rows) _row(e.syllabusId, r, pending, ValueKey('prow_${e.syllabusId}_${r.unit?.no}_${r.topic?.no}_${r.sub.no}')),
        if (k.earlier.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.row, bottom: EmSpacing.s4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ExcludeSemantics(child: Icon(Icons.history_rounded, size: 16, color: EmColors.onWarningContainer)),
              const SizedBox(width: EmSpacing.s4),
              Expanded(child: Text('PLANNED FOR EARLIER WEEKS, NOT COVERED YET', style: EmType.label.copyWith(color: EmColors.onWarningContainer))),
            ]),
          ),
          for (final r in k.earlier) _row(e.syllabusId, r, pending, ValueKey('erow_${e.syllabusId}_${r.unit?.no}_${r.topic?.no}_${r.sub.no}')),
        ],
      ]),
    );
  }

  Widget _row(String sid, PlannerRow r, Set<String> pending, Key key) {
    final u = r.unit?.no ?? 0, t = r.topic?.no ?? 0;
    final where = [if (r.topic != null && r.topic!.name.isNotEmpty) r.topic!.name, if (r.unit != null && r.unit!.name.isNotEmpty) r.unit!.name].join(' · ');
    return Row(key: key, children: [
      CoverageBox(
        covered: r.sub.isCovered,
        busy: pending.contains('s:$sid:$u:$t:${r.sub.no}'),
        onTap: () => _tick(c.syllabi.markSubTopic(sid, u, t, r.sub.no, !r.sub.isCovered)),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.sub.name, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
          if (where.isNotEmpty) Text(where, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
      ),
      if (r.sub.plannedWeek != null) ...[const SizedBox(width: EmSpacing.s8), AppTag('W${r.sub.plannedWeek}', style: EmTone.neutral)],
    ]);
  }
}
