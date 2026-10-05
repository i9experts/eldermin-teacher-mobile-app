import 'package:flutter/material.dart';
import '../../../../../core/models/home/class_snapshot.dart';
import '../../../../../core/models/home/messaging.dart';
import '../../../../../core/models/home/summaries.dart';
import '../../../../../core/models/home/teaching.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/home_time.dart';
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
      for (final tp in periods)
        _row(
          key: Key('period_${tp.period.periodNo}_${tp.period.startText}_${tp.phase.name}'),
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
  final void Function(HomeworkAssignment) onOpen;
  const HomeworkCard({super.key, required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      if (data.capped) 'Checked the ${data.assignmentsChecked} most recent assignments only.',
      if (data.failedLookups > 0) "Couldn't check ${data.failedLookups} assignment(s); counts may be low.",
    ];
    return Column(children: [
      AppCard(
        child: Row(children: [
          CustomText(text: '${data.totalUngraded}', fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: CustomText(text: data.totalUngraded == 1 ? 'submission waiting to be graded' : 'submissions waiting to be graded', color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      for (final i in data.items.take(3))
        _row(
          title: i.assignment.title.isEmpty ? 'Untitled assignment' : i.assignment.title,
          subtitle: [i.assignment.subject, i.assignment.classLabel].where((e) => e.isNotEmpty).join(' · '),
          trailing: AppTag('${i.ungraded} to grade', style: TagStyle.amber),
          onTap: () => onOpen(i.assignment),
        ),
      for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 4), child: CustomText(text: n, color: AppColors.faint, fontSize: 10.5)),
    ]);
  }
}

class LessonPlansCard extends StatelessWidget {
  final LessonPlanSummary data;
  final void Function(LessonPlan) onOpen;
  const LessonPlansCard({super.key, required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      StatsRow(items: [('${data.submitted.length}', 'Awaiting approval', null), ('${data.rejected.length}', 'Rejected', null)]),
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

class PtmList extends StatelessWidget {
  final List<PtmMeeting> meetings;
  final void Function(PtmMeeting) onOpen;
  const PtmList({super.key, required this.meetings, required this.onOpen});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final m in meetings.take(3))
          _row(
            title: m.studentName.isEmpty ? 'Parent meeting' : m.studentName,
            subtitle: [
              if (m.scheduledDate != null) shortUtcDateOf(m.scheduledDate!),
              if (m.timeRange.isNotEmpty) m.timeRange,
              if (m.guardianName.isNotEmpty) m.guardianName,
            ].join(' · '),
            trailing: AppTag(m.status == 'confirmed' ? 'Confirmed' : 'Requested',
                style: m.status == 'confirmed' ? TagStyle.green : TagStyle.amber),
            onTap: () => onOpen(m),
          ),
      ]);
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
          trailing: const AppTag('Covered', style: TagStyle.info),
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
