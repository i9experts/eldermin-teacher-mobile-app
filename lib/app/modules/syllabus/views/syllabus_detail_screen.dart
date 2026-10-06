import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/academic/syllabus_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show InfoLine;
import '../../lesson_plans/views/widgets/lesson_plan_widgets.dart' show NoteBox;
import '../controllers/syllabus_controller.dart';
import '../controllers/syllabus_detail_controller.dart';
import 'widgets/syllabus_widgets.dart';

/// One syllabus (`/syllabus/:id`): overall and per-unit / per-topic progress, tickable topics and sub-topics (optimistic, rolled back on
/// failure), and each topic's lessons (read-only). Approve / publish / delete / design edits are coordinator actions and are not offered.
class SyllabusDetailScreen extends GetView<SyllabusDetailController> {
  const SyllabusDetailScreen({super.key});

  SyllabusController get list => controller.list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Syllabus', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Future<void> _tick(BuildContext context, Future<MarkResult> f) async {
    final r = await f;
    if (r is MarkFailed && context.mounted) _snack(context, r.failure.message);
  }

  List<Widget> _content(BuildContext context, Syllabus s, Set<String> expanded, Set<String> pending) {
    final p = s.progress;
    return [
      CustomText(key: const Key('syl_title'), text: s.subjectName, fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor, height: 1.2),
      const SizedBox(height: 4),
      CustomText(text: [s.classLabel, s.term, s.academicYearLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 12),
      const SizedBox(height: 12),
      if (s.isBehind)
        const NoteBox(boxKey: Key('syl_behind'), icon: Icons.schedule_rounded, title: 'Behind schedule', body: 'Your school has flagged this syllabus as behind schedule.', fg: AppColors.redText, bg: AppColors.redBg),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProgressBlock(progress: p, barKey: const Key('syl_overall_bar')),
          const SizedBox(height: 10),
          if (s.teacherName.isNotEmpty) InfoLine(icon: Icons.person_outline_rounded, text: s.teacherName),
          if (s.totalWeeks > 0) InfoLine(icon: Icons.date_range_rounded, text: '${s.totalWeeks} weeks planned'),
          if (s.lastTrackedAt != null) InfoLine(icon: Icons.update_rounded, text: 'Last updated ${instantText(s.lastTrackedAt!)}'),
        ]),
      ),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('syl_open_planner'),
          onPressed: () => Get.toNamed(Routes.syllabusWeeklyPlanner),
          icon: const Icon(Icons.date_range_rounded, size: 18),
          label: const CustomText(text: 'Weekly planner', color: AppColors.primaryColor, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 8),
      if (s.units.isEmpty) const AppEmptyView(key: Key('syl_no_units'), icon: Icons.list_alt_rounded, title: 'No topics yet', subtitle: 'The school has not added units and topics to this syllabus.'),
      for (final u in s.units) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(children: [
            Expanded(child: CustomText(text: 'Unit ${u.no}: ${u.name}', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 13)),
            CustomText(key: ValueKey('syl_unit_pct_${u.no}'), text: u.progress.total == 0 ? '' : '${u.progress.percent}%', color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
          ]),
        ),
        for (final t in u.topics) _topic(context, s, u, t, expanded, pending),
      ],
      const SizedBox(height: 4),
      const CustomText(text: 'Ticking a topic tells the school that you covered it. Lessons are shown for reading only.', color: AppColors.muted, fontSize: 11),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (t.hasSubTopics)
            Padding(padding: const EdgeInsets.all(6), child: Icon(covered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 22, key: ValueKey('topic_state_${u.no}_${t.no}'), color: covered ? AppColors.secondryColor : AppColors.lightGrey5))
          else
            KeyedSubtree(
              key: ValueKey('tick_topic_${u.no}_${t.no}'),
              child: CoverageBox(covered: covered, busy: topicBusy, onTap: () => _tick(context, list.markTopic(s.id, u.no, t.no, !covered))),
            ),
          Expanded(
            child: InkWell(
              onTap: expandable ? () => c.toggleTopic(u.no, t.no) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: CustomText(text: '${t.no}. ${t.name}', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.black, maxLines: 3, overflow: TextOverflow.ellipsis)),
                  if (t.hasSubTopics) CustomText(key: ValueKey('topic_count_${u.no}_${t.no}'), text: '${t.progress.covered}/${t.progress.total}', color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
                  if (expandable) Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.muted),
                ]),
              ),
            ),
          ),
        ]),
        if (t.hasSubTopics)
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 4, 4), child: AppProgressBar(percent: t.progress.percent, color: t.progress.isComplete ? AppColors.secondryColor : AppColors.blue)),
        if (open && t.hasSubTopics)
          for (final sub in t.subTopics)
            Row(key: ValueKey('sub_${u.no}_${t.no}_${sub.no}'), children: [
              const SizedBox(width: 16),
              KeyedSubtree(
                key: ValueKey('tick_sub_${u.no}_${t.no}_${sub.no}'),
                child: CoverageBox(covered: sub.isCovered, busy: pending.contains('s:${s.id}:${u.no}:${t.no}:${sub.no}'), onTap: () => _tick(context, list.markSubTopic(s.id, u.no, t.no, sub.no, !sub.isCovered))),
              ),
              Expanded(child: CustomText(text: sub.name, fontSize: 12.5, color: AppColors.black)),
              if (sub.plannedWeek != null) AppTag('WEEK ${sub.plannedWeek}', style: TagStyle.neutral),
            ]),
        if (open && t.lessons.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(8, 8, 0, 4), child: CustomText(text: 'LESSONS (READ ONLY)', color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: l.title.isEmpty ? '(Untitled lesson)' : l.title, fontSize: 12.5, color: AppColors.primaryColor, fontWeight: FontWeight.w700)),
          if (l.link.isNotEmpty) const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }
}
