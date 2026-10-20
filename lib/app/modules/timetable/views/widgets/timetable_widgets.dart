import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../../core/utils/home_time.dart';
import '../../../../../core/utils/timetable_week.dart';
import '../../../../../core/widgets/app_widgets.dart';

/// One period: time column, "Subject · Class", room / split group, NOW / NEXT and Week A/B tags.
/// [compact] is the denser week-view variant.
class PeriodTile extends StatelessWidget {
  final TodayPeriod item;
  final bool compact;
  const PeriodTile({super.key, required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = item.period;
    final past = item.phase == PeriodPhase.past;
    final current = item.phase == PeriodPhase.current;
    final start = p.startMinutes != null ? formatHm(p.startMinutes!) : (p.startText.isEmpty ? '--:--' : p.startText);
    final end = p.endMinutes != null ? formatHm(p.endMinutes!) : p.endText;
    final subtitle = [
      if (p.room.isNotEmpty) 'Room ${p.room}',
      if (p.splitLabel != null) 'Group: ${p.splitLabel}',
    ].join(' · ');
    final tags = current || item.phase == PeriodPhase.next || p.weekCycleTag != null;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? EmSpacing.s8 : EmSpacing.row),
      child: EmCard(
        color: current ? EmColors.primaryContainer : EmColors.surface,
        padding: compact ? EmSpacing.cardPadCompact : EmSpacing.cardPad,
        radius: EmRadius.md,
        child: Row(children: [
          // the time column is as wide as its text needs (never wraps "08:00", whatever the text scale)
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(start, softWrap: false, style: EmType.valueSmall.copyWith(color: past ? EmColors.textTertiary : EmColors.ink)),
            Text(end, softWrap: false, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ]),
          const SizedBox(width: EmSpacing.row),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: past ? EmColors.textSecondary : EmColors.ink, fontWeight: FontWeight.w600)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ]),
          ),
          if (tags) ...[
            const SizedBox(width: EmSpacing.s8),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (current) const AppTag('NOW', style: TagStyle.green),
              if (item.phase == PeriodPhase.next) const AppTag('NEXT', style: TagStyle.amber),
              if (p.weekCycleTag != null) ...[
                if (current || item.phase == PeriodPhase.next) const SizedBox(height: EmSpacing.s4),
                AppTag('Week ${p.weekCycleTag}', style: TagStyle.neutral),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Sunday..Saturday strip for the selected week: previous / next week arrows above, the shared date strip below
/// (the selected day is filled, days with classes get a dot).
class TimetableWeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final Set<DateTime> withClasses;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const TimetableWeekStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
    this.withClasses = const {},
  });

  @override
  Widget build(BuildContext context) {
    final first = days.isEmpty ? today : days.first;
    return EmHeroCard(
      padding: const EdgeInsetsDirectional.all(EmSpacing.s12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          EmIconCircleButton(key: const Key('week_prev'), icon: Icons.chevron_left_rounded, semanticLabel: 'Previous week', tooltip: 'Previous week', onTap: onPrevious),
          Expanded(child: Text(weekRangeLabel(first), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(color: EmColors.ink))),
          EmIconCircleButton(key: const Key('week_next'), icon: Icons.chevron_right_rounded, semanticLabel: 'Next week', tooltip: 'Next week', onTap: onNext),
        ]),
        const SizedBox(height: EmSpacing.s8),
        EmDateStrip(days: days, selected: selected, onSelected: onSelect, markedDays: withClasses, dayKey: (d) => ValueKey('day_${d.year}-${d.month}-${d.day}')),
      ]),
    );
  }
}

/// Explains why A and B periods are both listed (the app never guesses the current week).
class WeekCycleNote extends StatelessWidget {
  const WeekCycleNote({super.key});

  @override
  Widget build(BuildContext context) => const EmInfoBanner(
        key: Key('week_cycle_note'),
        tone: EmTone.info,
        text: 'Some periods run only in Week A or Week B. Eldermin cannot tell which week it is, so both are listed and tagged.',
      );
}
