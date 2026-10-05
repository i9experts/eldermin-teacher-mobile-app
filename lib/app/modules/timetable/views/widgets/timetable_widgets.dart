import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/home_time.dart';
import '../../../../../core/utils/timetable_week.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';

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
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: current ? AppColors.pale : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: current ? AppColors.blue : AppColors.line, width: current ? 1.5 : 1),
      ),
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(text: start, fontWeight: FontWeight.w800, color: past ? AppColors.faint : AppColors.primaryColor, fontSize: 13),
            CustomText(text: end, color: AppColors.faint, fontSize: 10),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(
              text: [p.subject, p.classLabel].where((e) => e.isNotEmpty).join(' · '),
              fontWeight: FontWeight.w700,
              color: past ? AppColors.muted : AppColors.primaryColor,
              fontSize: 13,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              CustomText(text: subtitle, color: AppColors.muted, fontSize: 11, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        if (current || item.phase == PeriodPhase.next || p.weekCycleTag != null) ...[
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (current) const AppTag('NOW', style: TagStyle.green),
            if (item.phase == PeriodPhase.next) const AppTag('NEXT', style: TagStyle.amber),
            if (p.weekCycleTag != null) ...[
              if (current || item.phase == PeriodPhase.next) const SizedBox(height: 4),
              AppTag('Week ${p.weekCycleTag}', style: TagStyle.neutral),
            ],
          ]),
        ],
      ]),
    );
  }
}

/// Sunday..Saturday strip for the selected week, with previous / next week arrows.
/// Today has a ring, the selected day is filled, days with classes get a dot.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        IconButton(
          key: const Key('week_prev'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryColor),
        ),
        for (final d in days)
          Expanded(
            child: GestureDetector(
              key: ValueKey('day_${d.year}-${d.month}-${d.day}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(d),
              child: _DayBox(day: d, selected: sameDate(d, selected), isToday: sameDate(d, today), hasClasses: withClasses.any((w) => sameDate(w, d))),
            ),
          ),
        IconButton(
          key: const Key('week_next'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryColor),
        ),
      ]),
    );
  }
}

class _DayBox extends StatelessWidget {
  final DateTime day;
  final bool selected, isToday, hasClasses;
  const _DayBox({required this.day, required this.selected, required this.isToday, required this.hasClasses});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday && !selected ? AppColors.blue : Colors.transparent, width: 1.5),
      ),
      child: Column(children: [
        CustomText(text: weekdayShort(day).substring(0, 3), color: selected ? const Color(0xFFBFD8ED) : AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700),
        const SizedBox(height: 3),
        CustomText(text: '${day.day}', color: selected ? Colors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w800),
        const SizedBox(height: 3),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: hasClasses ? (selected ? Colors.white : AppColors.amber) : Colors.transparent, shape: BoxShape.circle),
        ),
      ]),
    );
  }
}

/// Explains why A and B periods are both listed (the app never guesses the current week).
class WeekCycleNote extends StatelessWidget {
  const WeekCycleNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('week_cycle_note'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.blue),
          SizedBox(width: 8),
          Expanded(
            child: CustomText(
              text: 'Some periods run only in Week A or Week B. Eldermin cannot tell which week it is, so both are listed and tagged.',
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ]),
      );
}
