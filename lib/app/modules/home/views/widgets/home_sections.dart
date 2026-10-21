import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/home/class_snapshot.dart';
import '../../../../../core/models/home/messaging.dart';
import '../../../../../core/models/home/summaries.dart';
import '../../../../../core/models/home/teaching.dart';
import '../../../../../core/utils/home_time.dart';
import '../../../../../core/utils/ptm_agenda.dart';

/// White rounded row card (REFERENCE_SPEC list row): optional leading widget,
/// two-line text, optional trailing. [highlight] fills it with the primary tint.
Widget _row({
  required String title,
  required String subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  bool highlight = false,
  Widget? leading,
  Key? key,
}) {
  return Padding(
    key: key,
    padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.row),
    child: EmCard(
      color: highlight ? EmColors.primaryContainer : EmColors.surface,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s16, vertical: EmSpacing.s12),
      child: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: EmSpacing.s12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: EmSpacing.s8), trailing],
      ]),
    ),
  );
}

Widget _iconChip(IconData icon, {Color bg = EmColors.primaryTint, Color fg = EmColors.primary}) => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: ExcludeSemantics(child: Icon(icon, color: fg, size: 22)),
    );

/// Existing [TagStyle]-style status -> [EmTone] (container + dark text).
EmChip _chip(String label, EmTone tone, {Key? key}) => EmChip.status(key: key, label: label, tone: tone);

/// Today's periods: past dimmed, current highlighted "NOW", next "NEXT".
class TimetableStrip extends StatelessWidget {
  final List<TodayPeriod> periods;
  const TimetableStrip({super.key, required this.periods});

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return EmCard(
        key: const Key('timetable_no_classes'),
        child: Row(children: [
          _iconChip(Icons.wb_sunny_outlined),
          const SizedBox(width: EmSpacing.s12),
          Expanded(child: Text('No classes today', style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
        ]),
      );
    }
    return Column(children: [
      for (final (i, tp) in periods.indexed)
        _row(
          key: ValueKey('period_$i'),
          highlight: tp.phase == PeriodPhase.current,
          // the time column grows with the text scale so "08:00" never wraps onto two lines
          leading: SizedBox(
            width: 52 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  tp.period.startMinutes != null ? formatHm(tp.period.startMinutes!) : (tp.period.startText.isEmpty ? '--:--' : tp.period.startText),
                  maxLines: 1,
                  softWrap: false,
                  style: EmType.valueSmall.copyWith(color: tp.phase == PeriodPhase.past ? EmColors.textSecondary : EmColors.ink)),
              Text(tp.period.endMinutes != null ? formatHm(tp.period.endMinutes!) : tp.period.endText,
                  maxLines: 1,
                  softWrap: false,
                  style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
            ]),
          ),
          title: [tp.period.subject, tp.period.classLabel].where((e) => e.isNotEmpty).join(' · '),
          subtitle: [
            if (tp.period.room.isNotEmpty) 'Room ${tp.period.room}',
            if (tp.period.splitLabel != null) tp.period.splitLabel!,
          ].join(' · '),
          trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (tp.phase == PeriodPhase.current) _chip('NOW', EmTone.success),
            if (tp.phase == PeriodPhase.next) _chip('NEXT', EmTone.warning),
            if (tp.period.weekCycleTag != null) ...[
              const SizedBox(height: EmSpacing.s4),
              _chip('Week ${tp.period.weekCycleTag}', EmTone.neutral),
            ],
          ]),
        ),
    ]);
  }
}

/// Class-teacher card: roster size + attendance-marked-today in a hero container
/// (ring + stat tiles), with the action button.
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
    final done = snap.state == AttendanceMarkState.complete;
    return Column(children: [
      EmHeroCard(
        padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Class teacher · ${snap.label}', maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s8),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('${snap.markedCount} / ${snap.rosterSize}', style: EmType.display.copyWith(color: EmColors.ink)),
                ),
                const SizedBox(height: EmSpacing.s8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: EmSpacing.s4),
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: done ? EmColors.success : EmColors.accent, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: EmSpacing.s8),
                  Expanded(child: Text(trend, style: EmType.label.copyWith(color: EmColors.ink))),
                ]),
              ]),
            ),
            const SizedBox(width: EmSpacing.s12),
            EmProgressRing(value: snap.percent / 100, size: 96, strokeWidth: 10, centerText: '${snap.percent}%', semanticLabel: 'Marked today ${snap.percent} percent'),
          ]),
          const SizedBox(height: EmSpacing.s16),
          EmStatTileRow(tiles: [
            EmStatTile(icon: Icons.groups_outlined, value: '${snap.rosterSize}', label: 'Students'),
            EmStatTile(icon: Icons.fact_check_outlined, value: '${snap.markedCount}', label: 'Marked today'),
          ]),
        ]),
      ),
      const SizedBox(height: EmSpacing.s12),
      EmPrimaryButton(
        key: const Key('mark_attendance_button'),
        label: 'Mark Attendance',
        icon: Icons.fact_check_outlined,
        onPressed: onMarkAttendance,
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
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.row),
        child: EmCard(
          child: Row(children: [
            Text('${data.totalUngraded}', key: const Key('homework_total'), style: EmType.display.copyWith(color: EmColors.primary)),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text(data.totalUngraded == 1 ? 'submission waiting to be graded' : 'submissions waiting to be graded', style: EmType.body.copyWith(color: EmColors.textSecondary))),
          ]),
        ),
      ),
      for (final i in data.items.take(_shown))
        _row(
          key: ValueKey('grading_${i.assignmentId}'),
          title: i.title.isEmpty ? 'Untitled assignment' : i.title,
          subtitle: [i.subject, i.classLabel].where((e) => e.isNotEmpty).join(' · '),
          trailing: _chip('${i.ungraded} to grade', EmTone.warning),
          onTap: () => onOpen(i),
        ),
      for (final n in notes) Padding(padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.s4), child: Text(n, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
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
      EmStatTileRow(tiles: [
        EmStatTile(
          key: const ValueKey('stat_tap_0'),
          icon: Icons.hourglass_empty_rounded,
          value: '${data.submitted.length}',
          label: 'Awaiting approval',
          onTap: onOpenFilter == null ? null : () => onOpenFilter!('submitted'),
        ),
        EmStatTile(
          key: const ValueKey('stat_tap_1'),
          icon: Icons.assignment_return_outlined,
          value: '${data.rejected.length}',
          label: 'Rejected',
          onTap: onOpenFilter == null ? null : () => onOpenFilter!('rejected'),
        ),
      ]),
      const SizedBox(height: EmSpacing.row),
      for (final p in data.rejected.take(3))
        _row(
          title: p.topic.isEmpty ? 'Untitled plan' : p.topic,
          subtitle: (p.rejectionReason != null && p.rejectionReason!.isNotEmpty)
              ? 'Rejected: ${p.rejectionReason}'
              : 'Rejected (no reason given)',
          trailing: _chip('Rejected', EmTone.error),
          onTap: () => onOpen(p),
        ),
      for (final p in data.submitted.take(3))
        _row(
          title: p.topic.isEmpty ? 'Untitled plan' : p.topic,
          subtitle: [p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '),
          trailing: _chip('Awaiting', EmTone.info),
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

  static (String, EmTone) _status(String s) => switch (s) {
        'confirmed' => ('Confirmed', EmTone.success),
        'requested' => ('Requested', EmTone.warning),
        'completed' => ('Completed', EmTone.success),
        'cancelled' => ('Cancelled', EmTone.error),
        'no_show' => ('No-show', EmTone.error),
        _ => (s.isEmpty ? 'Unknown' : s, EmTone.neutral),
      };

  Widget _label(String text, {Key? key, Widget? trailing, VoidCallback? onTap}) => InkWell(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: onTap == null ? 32 : 48),
          child: Row(children: [
            Expanded(child: Text(text, style: EmType.label.copyWith(color: EmColors.textSecondary))),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _meeting(PtmMeeting m, {bool today = false, bool dim = false}) {
    final (label, tone) = _status(m.status);
    return _row(
      key: ValueKey('ptm_${m.id}'),
      title: m.studentName.isEmpty ? 'Parent meeting' : m.studentName,
      subtitle: [
        if (!today && m.scheduledDate != null) shortUtcDateOf(m.scheduledDate!),
        if (m.timeRange.isNotEmpty) m.timeRange,
        if (m.guardianName.isNotEmpty) m.guardianName,
      ].join(' · '),
      trailing: _chip(label, dim && (m.status == 'confirmed' || m.status == 'requested') ? EmTone.neutral : tone),
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
          trailing: Icon(_earlierOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: EmColors.textSecondary, size: 22),
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
          trailing: _chip('Covering', EmTone.warning),
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
              ? _chip('Not covered yet', EmTone.warning, key: const Key('sub_chip_open'))
              : _chip('Covered', EmTone.info),
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
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: EmSpacing.row),
        child: EmCard(
          onTap: onOpen,
          child: Row(children: [
            _iconChip(Icons.mark_email_unread_outlined),
            const SizedBox(width: EmSpacing.s12),
            Expanded(
                child: Text('$n${data.mayUndercount ? '+' : ''} unread ${n == 1 ? 'conversation' : 'conversations'}',
                    style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
            const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
          ]),
        ),
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
