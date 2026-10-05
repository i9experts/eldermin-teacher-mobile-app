import 'package:flutter/material.dart';
import '../../../../../core/models/classroom/attendance_models.dart';
import '../../../../../core/models/classroom/student_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../components/custom_text.dart';

/// Foreground / background colours per status.
({Color fg, Color bg}) statusColors(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return (fg: AppColors.greenText, bg: AppColors.greenBg);
    case AttendanceStatus.absent:
      return (fg: AppColors.redText, bg: AppColors.redBg);
    case AttendanceStatus.late:
      return (fg: AppColors.amberText, bg: AppColors.amberBg);
    case AttendanceStatus.excused:
      return (fg: AppColors.blue, bg: AppColors.pale);
    case AttendanceStatus.halfDay:
      return (fg: AppColors.purple, bg: AppColors.purpleBg);
  }
}

/// Short chip text: the five statuses must fit one row on a phone.
String chipLabel(AttendanceStatus s) => s == AttendanceStatus.halfDay ? 'Half' : s.label;

/// One student with the five status toggles. A row without a status can be highlighted
/// ([highlightMissing]) after the teacher tried to submit with students unmarked.
class StudentAttendanceRow extends StatelessWidget {
  final StudentSummary student;
  final AttendanceStatus? status;
  final String? legacyStatus;
  final bool enabled;
  final bool highlightMissing;
  final ValueChanged<AttendanceStatus> onSelect;

  const StudentAttendanceRow({
    super.key,
    required this.student,
    required this.status,
    required this.onSelect,
    this.legacyStatus,
    this.enabled = true,
    this.highlightMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    final missing = status == null;
    final warn = missing && highlightMissing;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warn ? AppColors.amberBg : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: warn ? AppColors.amber : AppColors.line, width: warn ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(11)),
            child: CustomText(text: student.initials, color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomText(text: student.fullName, fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
              CustomText(
                text: [
                  if ((student.rollNumber ?? '').isNotEmpty) 'Roll ${student.rollNumber}',
                  if ((student.grNo ?? '').isNotEmpty) student.grNo!,
                ].join(' · '),
                color: AppColors.faint,
                fontSize: 10,
              ),
            ]),
          ),
          if (missing)
            CustomText(
              key: const Key('row_not_marked'),
              text: legacyStatus != null ? 'Saved as "$legacyStatus"' : 'Not marked',
              color: warn ? AppColors.amberText : AppColors.faint,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final s in AttendanceStatus.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s == AttendanceStatus.values.last ? 0 : 4),
                child: _StatusChip(
                  key: ValueKey('chip_${student.id}_${s.wire}'),
                  status: s,
                  selected: status == s,
                  enabled: enabled,
                  onTap: () => onSelect(s),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AttendanceStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _StatusChip({super.key, required this.status, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = statusColors(status);
    return Semantics(
      button: true,
      selected: selected,
      label: '${status.label}${selected ? ', selected' : ''}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.fg : (enabled ? c.bg : AppColors.background),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? c.fg : c.bg),
          ),
          child: CustomText(
            text: chipLabel(status),
            color: selected ? Colors.white : (enabled ? c.fg : AppColors.faint),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Counts as small coloured pills (Present 24, Absent 2 ...). Zero counts are hidden unless [showZero].
class StatusCountPills extends StatelessWidget {
  final StatusCounts counts;
  final bool showZero;
  const StatusCountPills({super.key, required this.counts, this.showZero = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final s in AttendanceStatus.values)
        if (showZero || counts.of(s) > 0)
          Container(
            key: ValueKey('count_${s.wire}'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusColors(s).bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: CustomText(text: '${s.label} ${counts.of(s)}', color: statusColors(s).fg, fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
      if (counts.other > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: CustomText(text: 'Other ${counts.other}', color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
    ]);
  }
}
