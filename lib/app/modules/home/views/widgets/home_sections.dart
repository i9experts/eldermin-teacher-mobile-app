import 'package:flutter/material.dart';
import '../../../../../core/models/home/class_snapshot.dart';
import '../../../../../core/models/home/messaging.dart';
import '../../../../../core/models/home/summaries.dart';
import '../../../../../core/models/home/teaching.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/home_time.dart';
import '../../../../../core/utils/ptm_agenda.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../../core/widgets/hero_card.dart';
import '../../../../components/custom_text.dart';

Widget _row({
  required String title,
  required String subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  bool highlight = false,
  Widget? leading,
  Key? key,
}) {
  return Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: highlight ? AppColors.pale : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: highlight ? AppColors.blue : AppColors.line, width: highlight ? 1.5 : 1),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (leading != null) ...[leading, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CustomText(text: title, fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                CustomText(text: subtitle, color: AppColors.muted, fontSize: 11, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
      ),
    ),
  );
}

/// Today's periods: past dimmed, current highlighted "NOW", next "NEXT".
class TimetableStrip extends StatelessWidget {
  final List<TodayPeriod> periods;
  const TimetableStrip({super.key, required this.periods});

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const AppCard(
        key: Key('timetable_no_classes'),
        child: Row(children: [
          Icon(Icons.wb_sunny_outlined, color: AppColors.faint, size: 22),
          SizedBox(width: 12),
          CustomText(text: 'No classes today', fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 13),
        ]),
      );
    }
    return Column(children: [
      for (final (i, tp) in periods.indexed)
        _row(
          key: ValueKey('period_$i'),
          highlight: tp.phase == PeriodPhase.current,
          leading: SizedBox(
            width: 50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomText(
                  text: tp.period.startMinutes != null ? formatHm(tp.period.startMinutes!) : (tp.period.startText.isEmpty ? '--:--' : tp.period.startText),
                  fontWeight: FontWeight.w800,
                  color: tp.phase == PeriodPhase.past ? AppColors.faint : AppColors.primaryColor,
                  fontSize: 13),
              CustomText(
                  text: tp.period.endMinutes != null ? formatHm(tp.period.endMinutes!) : tp.period.endText,
                  color: AppColors.faint,
                  fontSize: 10),
            ]),
          ),
          title: [tp.period.subject, tp.period.classLabel].where((e) => e.isNotEmpty).join(' · '),
          subtitle: [
            if (tp.period.room.isNotEmpty) 'Room ${tp.period.room}',
            if (tp.period.splitLabel != null) tp.period.splitLabel!,
          ].join(' · '),
          trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (tp.phase == PeriodPhase.current) const AppTag('NOW', style: TagStyle.green),
            if (tp.phase == PeriodPhase.next) const AppTag('NEXT', style: TagStyle.amber),
            if (tp.period.weekCycleTag != null) ...[
              const SizedBox(height: 4),
              AppTag('Week ${tp.period.weekCycleTag}', style: TagStyle.neutral),
            ],
          ]),
        ),
    ]);
  }
}

/// Class-teacher card: roster size + attendance-marked-today, with the action button.
class ClassTeacherCard extends StatelessWidget {
  final ClassAttendanceSnapshot snap;
  final VoidCallback onMarkAttendance;
  const ClassTeacherCard({super.key, required this.snap, required this.onMarkAttendance});

  @override
  Widget build(BuildContext context) {
    final String trend;
    switch (snap.state) {
      case AttendanceMarkState.notMarked:
        trend = "Attendance isn't marked yet today";
      case AttendanceMarkState.partial:
        trend = 'Attendance partly marked today';
      case AttendanceMarkState.complete:
        trend = 'Attendance marked today';
    }
    return Column(children: [
      HeroCard(
        kicker: 'Class teacher · ${snap.label}',
        value: '${snap.markedCount} / ${snap.rosterSize}',
        trend: trend,
        trendWarn: snap.state != AttendanceMarkState.complete,
        percent: snap.percent,
        metrics: [('${snap.rosterSize}', 'Students'), ('${snap.markedCount}', 'Marked today')],
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('mark_attendance_button'),
          onPressed: onMarkAttendance,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const CustomText(text: 'Mark Attendance', color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

class HomeworkCard extends StatelessWidget {
  final HomeworkToGrade data;
  final void Function(GradingRow) onOpen;
  const HomeworkCard({super.key, required this.data, required this.onOpen});

  static const int _shown = 5;

  @override
  Widget build(BuildContext context) {
    final fallback = data.source == GradingSource.fallback;
    final more = data.items.length - _shown;
    final notes = <String>[
      if (fallback && data.capped) 'Checked the ${data.assignmentsChecked} most recent assignments only.',
      if (fallback && data.failedLookups > 0) "Couldn't check ${data.failedLookups} assignment(s); counts may be low.",
      if (more > 0) '+ $more more ${more == 1 ? 'assignment' : 'assignments'} with work to grade.',
      if (data.unlistedUngraded > 0) '${data.unlistedUngraded} more waiting in assignments not listed here.',
    ];
    return Column(children: [
      AppCard(
        child: Row(children: [
          CustomText(text: '${data.totalUngraded}', key: const Key('homework_total'), fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: CustomText(text: data.totalUngraded == 1 ? 'submission waiting to be graded' : 'submissions waiting to be graded', color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      for (final i in data.items.take(_shown))
        _row(
          key: ValueKey('grading_${i.assignmentId}'),
          title: i.title.isEmpty ? 'Untitled assignment' : i.title,
          subtitle: [i.subject, i.classLabel].where((e) => e.isNotEmpty).join(' · '),
          trailing: AppTag('${i.ungraded} to grade', style: TagStyle.amber),
          onTap: () => onOpen(i),
        ),
      for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 4), child: CustomText(text: n, color: AppColors.faint, fontSize: 10.5)),
    ]);
  }
}

class LessonPlansCard extends StatelessWidget {
  final LessonPlanSummary data;
  final void Function(LessonPlan) onOpen;

  /// Opens the lesson plans list pre-filtered to a status (`'submitted'` / `'rejected'`).
  final void Function(String status)? onOpenFilter;
  const LessonPlansCard({super.key, required this.data, required this.onOpen, this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      StatsRow(
        items: [('${data.submitted.length}', 'Awaiting approval', null), ('${data.rejected.length}', 'Rejected', null)],
        onTaps: onOpenFilter == null ? null : [() => onOpenFilter!('submitted'), () => onOpenFilter!('rejected')],
      ),
      const SizedBox(height: 8),
      for (final p in data.rejected.take(3))
        _row(
          title: p.topic.isEmpty ? 'Untitled plan' : p.topic,
          subtitle: (p.rejectionReason != null && p.rejectionReason!.isNotEmpty)
              ? 'Rejected: ${p.rejectionReason}'
              : 'Rejected (no reason given)',
          trailing: const AppTag('Rejected', style: TagStyle.red),
          onTap: () => onOpen(p),
        ),
      for (final p in data.submitted.take(3))
        _row(
          title: p.topic.isEmpty ? 'Untitled plan' : p.topic,
          subtitle: [p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '),
          trailing: const AppTag('Awaiting', style: TagStyle.info),
          onTap: () => onOpen(p),
        ),
    ]);
  }
}

/// Parent meetings: remaining today first, then a collapsible "Earlier today" group (already past
/// or completed/cancelled/no_show, with a status chip), then later upcoming meetings.
class PtmList extends StatefulWidget {
  final PtmAgenda agenda;
  final void Function(PtmMeeting) onOpen;
  const PtmList({super.key, required this.agenda, required this.onOpen});

  @override
  State<PtmList> createState() => _PtmListState();
}

class _PtmListState extends State<PtmList> {
  bool _earlierOpen = false;

  static (String, TagStyle) _status(String s) => switch (s) {
        'confirmed' => ('Confirmed', TagStyle.green),
        'requested' => ('Requested', TagStyle.amber),
        'completed' => ('Completed', TagStyle.green),
        'cancelled' => ('Cancelled', TagStyle.red),
        'no_show' => ('No-show', TagStyle.red),
        _ => (s.isEmpty ? 'Unknown' : s, TagStyle.neutral),
      };

  Widget _label(String text, {Key? key, Widget? trailing, VoidCallback? onTap}) => InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(children: [
            Expanded(child: CustomText(text: text, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _meeting(PtmMeeting m, {bool today = false, bool dim = false}) {
    final (label, style) = _status(m.status);
    return _row(
      key: ValueKey('ptm_${m.id}'),
      title: m.studentName.isEmpty ? 'Parent meeting' : m.studentName,
      subtitle: [
        if (!today && m.scheduledDate != null) shortUtcDateOf(m.scheduledDate!),
        if (m.timeRange.isNotEmpty) m.timeRange,
        if (m.guardianName.isNotEmpty) m.guardianName,
      ].join(' · '),
      trailing: AppTag(label, style: dim && (m.status == 'confirmed' || m.status == 'requested') ? TagStyle.neutral : style),
      onTap: () => widget.onOpen(m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agenda;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (a.remainingToday.isNotEmpty) ...[
        _label('Today', key: const Key('ptm_label_today')),
        for (final m in a.remainingToday.take(5)) _meeting(m, today: true),
      ],
      if (a.earlierToday.isNotEmpty) ...[
        _label(
          'Earlier today (${a.earlierToday.length})',
          key: const Key('ptm_earlier_toggle'),
          onTap: () => setState(() => _earlierOpen = !_earlierOpen),
          trailing: Icon(_earlierOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.faint, size: 20),
        ),
        if (_earlierOpen) for (final m in a.earlierToday) _meeting(m, today: true, dim: true),
      ],
      if (a.upcoming.isNotEmpty) ...[
        _label('Upcoming', key: const Key('ptm_label_upcoming')),
        for (final m in a.upcoming.take(3)) _meeting(m),
      ],
    ]);
  }
}

class SubstitutionsCard extends StatelessWidget {
  final SubstitutionsToday data;
  final void Function(Substitution) onOpen;
  const SubstitutionsCard({super.key, required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    String when(Substitution s) => [s.startTime, s.endTime].where((e) => e.isNotEmpty).join(' - ');
    return Column(children: [
      for (final s in data.covering)
        _row(
          key: ValueKey('sub_covering_${s.id}'),
          title: "You're covering ${s.subject.isEmpty ? 'a class' : s.subject}",
          subtitle: [s.classLabel, when(s), if (s.originalTeacherName.isNotEmpty) 'for ${s.originalTeacherName}'].where((e) => e.isNotEmpty).join(' · '),
          trailing: const AppTag('Covering', style: TagStyle.amber),
          onTap: () => onOpen(s),
        ),
      for (final s in data.covered)
        _row(
          key: ValueKey('sub_covered_${s.id}'),
          title: '${s.subject.isEmpty ? 'Your class' : s.subject} is being covered',
          subtitle: [
            s.classLabel,
            when(s),
            s.substituteTeacherName.isNotEmpty ? 'by ${s.substituteTeacherName}' : 'no substitute assigned yet',
          ].where((e) => e.isNotEmpty).join(' · '),
          // No substitute yet = nobody covers it: do not say "Covered" (seen on the local run, LOCAL_VERIFICATION s12).
          trailing: s.substituteTeacherName.isEmpty
              ? const AppTag('Not covered yet', style: TagStyle.amber, key: Key('sub_chip_open'))
              : const AppTag('Covered', style: TagStyle.info),
          onTap: () => onOpen(s),
        ),
    ]);
  }
}

class MessagesSummary extends StatelessWidget {
  final ThreadsResult data;
  final VoidCallback onOpen;
  const MessagesSummary({super.key, required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final n = data.unreadCount;
    return Column(children: [
      AppCard(
        onTap: onOpen,
        child: Row(children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
              child: CustomText(
                  text: '$n${data.mayUndercount ? '+' : ''} unread ${n == 1 ? 'conversation' : 'conversations'}',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                  fontSize: 13)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        ]),
      ),
      for (final t in data.unreadThreads.take(3))
        _row(
          title: t.studentName.isNotEmpty ? '${t.guardianName.isEmpty ? 'Parent' : t.guardianName} · ${t.studentName}' : t.guardianName,
          subtitle: t.lastMessagePreview.isEmpty ? t.subject : t.lastMessagePreview,
          onTap: onOpen,
        ),
    ]);
  }
}
