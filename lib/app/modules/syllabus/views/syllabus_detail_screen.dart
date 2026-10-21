import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show InfoLine;
import '../../lesson_plans/views/widgets/lesson_plan_widgets.dart' show NoteBox;
import '../controllers/syllabus_controller.dart';
import '../controllers/syllabus_detail_controller.dart';
import 'widgets/syllabus_widgets.dart';
import '../../../../core/design/design.dart';

/// One syllabus (`/syllabus/:id`): overall and per-unit / per-topic progress, tickable topics and sub-topics (optimistic, rolled back on
/// failure), and each topic's lessons (read-only). Approve / publish / delete / design edits are coordinator actions and are not offered.
class SyllabusDetailScreen extends GetView<SyllabusDetailController> {
  const SyllabusDetailScreen({super.key});

  SyllabusController get list => controller.list;

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Syllabus'),
      body: Obx(() {
        final c = controller;
        // The list controller owns the syllabus after the first load (ticks update it), so read it reactively; the detail state covers the
        // loading / forbidden / not-mine / error cases.
        final fromList = list.byId(c.id);
        final state = fromList != null ? SectionState<Syllabus>.data(fromList) : c.state.value;
        final expanded = c.expanded.toSet();
        final pending = list.pending.toSet();
        return ScreenStateView<Syllabus>(
          state: state,
          onRefresh: () => c.load(force: true),
          onRetry: () => c.load(force: true),
          emptyTitle: 'Not found',
          builder: (s) => _content(context, s, expanded, pending),
        );
      }),
    );
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _tick(BuildContext context, Future<MarkResult> f) async {
    final r = await f;
    if (r is MarkFailed && context.mounted) _snack(context, r.failure.message);
  }

  List<Widget> _content(BuildContext context, Syllabus s, Set<String> expanded, Set<String> pending) {
    final p = s.progress;
    return [
      Text(s.subjectName, key: const Key('syl_title'), style: EmType.title.copyWith(color: EmColors.ink)),
      const SizedBox(height: EmSpacing.s4),
      Text([s.classLabel, s.term, s.academicYearLabel].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
      const SizedBox(height: EmSpacing.row),
      if (s.isBehind) const NoteBox(boxKey: Key('syl_behind'), icon: Icons.schedule_rounded, title: 'Behind schedule', body: 'Your school has flagged this syllabus as behind schedule.', tone: EmTone.error),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProgressBlock(progress: p, barKey: const Key('syl_overall_bar')),
          const SizedBox(height: EmSpacing.row),
          if (s.teacherName.isNotEmpty) InfoLine(icon: Icons.person_outline_rounded, text: s.teacherName),
          if (s.totalWeeks > 0) InfoLine(icon: Icons.date_range_rounded, text: '${s.totalWeeks} weeks planned'),
          if (s.lastTrackedAt != null) InfoLine(icon: Icons.update_rounded, text: 'Last updated ${instantText(s.lastTrackedAt!)}'),
        ]),
      ),
      EmSecondaryButton(key: const Key('syl_open_planner'), expand: true, icon: Icons.date_range_rounded, label: 'Weekly planner', onPressed: () => Get.toNamed(Routes.syllabusWeeklyPlanner)),
      const SizedBox(height: EmSpacing.s8),
      if (s.units.isEmpty) const AppEmptyView(key: Key('syl_no_units'), icon: Icons.list_alt_rounded, title: 'No topics yet', subtitle: 'The school has not added units and topics to this syllabus.'),
      for (final u in s.units) ...[
        Padding(
          padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8),
          child: Row(children: [
            Expanded(child: Text('Unit ${u.no}: ${u.name}', style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
            Text(u.progress.total == 0 ? '' : '${u.progress.percent}%', key: ValueKey('syl_unit_pct_${u.no}'), style: EmType.valueSmall.copyWith(color: EmColors.textSecondary)),
          ]),
        ),
        for (final t in u.topics) _topic(context, s, u, t, expanded, pending),
      ],
      const SizedBox(height: EmSpacing.s4),
      Text('Ticking a topic tells the school that you covered it. Lessons are shown for reading only.', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
    ];
  }

  Widget _topic(BuildContext context, Syllabus s, SyllabusUnit u, SyllabusTopic t, Set<String> expanded, Set<String> pending) {
    final c = controller;
    final open = expanded.contains(SyllabusDetailController.topicKey(u.no, t.no));
    final expandable = t.hasSubTopics || t.lessons.isNotEmpty;
    final topicBusy = pending.contains('s:${s.id}:${u.no}:${t.no}:-');
    final covered = t.covered;
    return AppCard(
      key: ValueKey('topic_${u.no}_${t.no}'),
      padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s4, EmSpacing.s4, EmSpacing.s12, EmSpacing.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (t.hasSubTopics)
            SizedBox(
              width: EmSpacing.minTouch,
              height: EmSpacing.minTouch,
              child: Center(child: Icon(covered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 24, key: ValueKey('topic_state_${u.no}_${t.no}'), color: covered ? EmColors.success : EmColors.textSecondary)),
            )
          else
            KeyedSubtree(
              key: ValueKey('tick_topic_${u.no}_${t.no}'),
              child: CoverageBox(covered: covered, busy: topicBusy, onTap: () => _tick(context, list.markTopic(s.id, u.no, t.no, !covered))),
            ),
          Expanded(
            child: InkWell(
              onTap: expandable ? () => c.toggleTopic(u.no, t.no) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
                child: Row(children: [
                  Expanded(child: Text('${t.no}. ${t.name}', maxLines: 3, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
                  if (t.hasSubTopics) Text('${t.progress.covered}/${t.progress.total}', key: ValueKey('topic_count_${u.no}_${t.no}'), style: EmType.valueSmall.copyWith(color: EmColors.textSecondary)),
                  if (expandable) ExcludeSemantics(child: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: EmColors.textSecondary)),
                ]),
              ),
            ),
          ),
        ]),
        if (t.hasSubTopics)
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s8, 0, EmSpacing.s4, EmSpacing.s8), child: AppProgressBar(percent: t.progress.percent, color: t.progress.isComplete ? EmColors.success : EmColors.primary)),
        if (open && t.hasSubTopics)
          for (final sub in t.subTopics)
            Row(key: ValueKey('sub_${u.no}_${t.no}_${sub.no}'), children: [
              const SizedBox(width: EmSpacing.s16),
              KeyedSubtree(
                key: ValueKey('tick_sub_${u.no}_${t.no}_${sub.no}'),
                child: CoverageBox(covered: sub.isCovered, busy: pending.contains('s:${s.id}:${u.no}:${t.no}:${sub.no}'), onTap: () => _tick(context, list.markSubTopic(s.id, u.no, t.no, sub.no, !sub.isCovered))),
              ),
              Expanded(child: Text(sub.name, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400))),
              if (sub.plannedWeek != null) ...[const SizedBox(width: EmSpacing.s8), AppTag('WEEK ${sub.plannedWeek}', style: EmTone.neutral)],
            ]),
        if (open && t.lessons.isNotEmpty) ...[
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s8, EmSpacing.s8, 0, EmSpacing.s4), child: Text('LESSONS (READ ONLY)', style: EmType.label.copyWith(color: EmColors.textSecondary))),
          for (final l in t.lessons) _lesson(context, u.no, t.no, l),
        ],
      ]),
    );
  }

  Widget _lesson(BuildContext context, int unitNo, int topicNo, SyllabusLesson l) {
    final icon = switch (l.type) {
      'video' => Icons.play_circle_outline_rounded,
      'document' => Icons.description_outlined,
      'reading' => Icons.menu_book_outlined,
      _ => Icons.link_rounded,
    };
    return InkWell(
      key: ValueKey('lesson_${unitNo}_${topicNo}_${l.no}'),
      onTap: l.link.isEmpty
          ? null
          : () async {
              final ok = await controller.openLesson(l);
              if (!ok && context.mounted) _snack(context, "Couldn't open this link.");
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s8),
          child: Row(children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: EmColors.primary)),
            const SizedBox(width: EmSpacing.s8),
            Expanded(child: Text(l.title.isEmpty ? '(Untitled lesson)' : l.title, style: EmType.body.copyWith(color: EmColors.primary, fontWeight: FontWeight.w600))),
            if (l.link.isNotEmpty) const ExcludeSemantics(child: Icon(Icons.open_in_new_rounded, size: 18, color: EmColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
