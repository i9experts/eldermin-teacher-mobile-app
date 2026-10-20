import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/classroom/attendance_models.dart';
import '../../../../../core/models/classroom/student_models.dart';

/// Foreground / background colours per status (semantic container + dark text; half-day uses the violet `statusLeave` pair).
({Color fg, Color bg}) statusColors(AttendanceStatus s) {
  final t = statusTone(s);
  return (fg: t.foreground, bg: t.background);
}

EmTone statusTone(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return EmTone.success;
    case AttendanceStatus.absent:
      return EmTone.error;
    case AttendanceStatus.late:
      return EmTone.warning;
    case AttendanceStatus.excused:
      return EmTone.info;
    case AttendanceStatus.halfDay:
      return EmTone.leave;
  }
}

/// Every status has its own glyph next to its label, so the five states never rely on colour alone.
IconData statusIcon(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return Icons.check_rounded;
    case AttendanceStatus.absent:
      return Icons.close_rounded;
    case AttendanceStatus.late:
      return Icons.schedule_rounded;
    case AttendanceStatus.excused:
      return Icons.event_note_rounded;
    case AttendanceStatus.halfDay:
      return Icons.contrast_rounded;
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
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmCard(
        color: warn ? EmColors.warningContainer : EmColors.surface,
        padding: EmSpacing.cardPadCompact,
        radius: EmRadius.md,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            EmAvatar(initials: student.initials, size: 40),
            const SizedBox(width: EmSpacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(student.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600)),
                Text(
                  [
                    if ((student.rollNumber ?? '').isNotEmpty) 'Roll ${student.rollNumber}',
                    if ((student.grNo ?? '').isNotEmpty) student.grNo!,
                  ].join(' · '),
                  style: EmType.caption.copyWith(color: EmColors.textSecondary),
                ),
              ]),
            ),
            if (missing)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: EmSpacing.s8),
                child: Text(
                  legacyStatus != null ? 'Saved as "$legacyStatus"' : 'Not marked',
                  key: const Key('row_not_marked'),
                  style: EmType.caption.copyWith(color: warn ? EmColors.onWarningContainer : EmColors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          const SizedBox(height: EmSpacing.s12),
          _Toggles(student: student, status: status, enabled: enabled, onSelect: onSelect),
        ]),
      ),
    );
  }
}

/// The five toggles in ONE row when every label fits at the current width and text scale, else 3 + 2 (a label is never truncated).
class _Toggles extends StatelessWidget {
  final StudentSummary student;
  final AttendanceStatus? status;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onSelect;
  const _Toggles({required this.student, required this.status, required this.enabled, required this.onSelect});

  static const double _gap = EmSpacing.s4;

  static double _need(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final s in AttendanceStatus.values) {
      final tp = TextPainter(text: TextSpan(text: chipLabel(s), style: EmType.caption.copyWith(fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
      if (tp.width > widest) widest = tp.width;
    }
    return widest + 2 * EmSpacing.s4 + 2;
  }

  @override
  Widget build(BuildContext context) {
    final need = _need(context);
    return LayoutBuilder(builder: (context, c) {
      final n = AttendanceStatus.values.length;
      final fitsOne = (c.maxWidth - _gap * (n - 1)) / n >= need;
      final perRow = fitsOne ? n : 3;
      final w = (c.maxWidth - _gap * (perRow - 1)) / perRow;
      return Wrap(spacing: _gap, runSpacing: _gap, children: [
        for (final s in AttendanceStatus.values)
          SizedBox(
            width: w,
            child: _StatusToggle(key: ValueKey('chip_${student.id}_${s.wire}'), status: s, selected: status == s, enabled: enabled, onTap: () => onSelect(s)),
          ),
      ]);
    });
  }
}

class _StatusToggle extends StatelessWidget {
  final AttendanceStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _StatusToggle({super.key, required this.status, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = statusColors(status);
    // Selected = solid dark fill + white glyph and label; unselected = tone container + dark label; read-only unselected = quiet tint.
    final bg = selected ? c.fg : (enabled ? c.bg : EmColors.primaryTint);
    final fg = selected ? EmColors.surface : (enabled ? c.fg : EmColors.textTertiary);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${status.label}${selected ? ', selected' : ''}',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: bg,
        borderRadius: EmRadius.smAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: EmRadius.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s4, vertical: EmSpacing.s8),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(statusIcon(status), size: 18, color: fg),
                const SizedBox(height: EmSpacing.s2),
                Text(chipLabel(status), maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: EmType.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Counts as small status chips (Present 24, Absent 2 ...) with the status glyph. Zero counts are hidden unless [showZero].
class StatusCountPills extends StatelessWidget {
  final StatusCounts counts;
  final bool showZero;
  const StatusCountPills({super.key, required this.counts, this.showZero = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
      for (final s in AttendanceStatus.values)
        if (showZero || counts.of(s) > 0) EmChip.status(key: ValueKey('count_${s.wire}'), label: '${s.label} ${counts.of(s)}', tone: statusTone(s), icon: statusIcon(s)),
      if (counts.other > 0) EmChip.status(label: 'Other ${counts.other}', tone: EmTone.neutral, icon: Icons.help_outline_rounded),
    ]);
  }
}
