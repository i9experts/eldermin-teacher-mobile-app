import 'package:flutter/material.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_text.dart';

/// One calendar entry as a card: colour bar (colour of its type), title, type tag, time / span.
class CalendarEntryCard extends StatelessWidget {
  final CalendarEntry entry;
  final VoidCallback? onTap;
  const CalendarEntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return AppCard(
      key: ValueKey('cal_entry_${e.id}'),
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, decoration: BoxDecoration(color: e.color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: CustomText(text: e.title, fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.primaryColor)),
                  const SizedBox(width: 8),
                  _TypeChip(type: e.type, color: e.color),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(child: CustomText(text: entrySubtitle(e), fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ]),
                if (e.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: e.description, fontSize: 11.5, color: AppColors.muted, height: 1.35, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final CalendarEventType type;
  final Color color;
  const _TypeChip({required this.type, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: CustomText(text: type.label.toUpperCase(), fontSize: 9, fontWeight: FontWeight.w800, color: color),
      );
}

/// Colour legend of the types that appear in [types] (only those: no fabricated categories).
class CalendarLegend extends StatelessWidget {
  final Iterable<CalendarEventType> types;
  const CalendarLegend({super.key, required this.types});

  @override
  Widget build(BuildContext context) {
    final list = types.toSet().toList()..sort((a, b) => a.index.compareTo(b.index));
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        for (final t in list)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            CustomText(text: t.label, fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600),
          ]),
      ]),
    );
  }
}
