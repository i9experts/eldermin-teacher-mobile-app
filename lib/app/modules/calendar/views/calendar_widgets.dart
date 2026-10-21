import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/utils/calendar_format.dart';
import '../../../../core/widgets/app_widgets.dart' show AppCard;

/// One calendar entry as a card: colour bar (colour of its type), title, type label (dot + ink text), time / span. The bar is decoration:
/// the type is always also said in words.
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
          Container(width: EmSpacing.s8 - EmSpacing.s2, decoration: BoxDecoration(color: e.color, borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(EmRadius.card)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(EmSpacing.s12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: EmSpacing.s4),
                Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _TypeChip(type: e.type, color: e.color),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const ExcludeSemantics(child: Icon(Icons.schedule_rounded, size: 16, color: EmColors.textSecondary)),
                    const SizedBox(width: EmSpacing.s4),
                    Flexible(child: Text(entrySubtitle(e), style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600))),
                  ]),
                ]),
                if (e.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Event-type label: a dot in the event colour plus the label in ink. The
/// colour is never used for text, so a server-supplied hex cannot fail contrast.
class CalendarTypeLabel extends StatelessWidget {
  final Color color;
  final String label;
  final double dotSize;
  const CalendarTypeLabel({super.key, required this.color, required this.label, this.dotSize = 10});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(key: const Key('cal_type_dot'), width: dotSize, height: dotSize, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: EmSpacing.s8),
        Flexible(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
      ]);
}

class _TypeChip extends StatelessWidget {
  final CalendarEventType type;
  final Color color;
  const _TypeChip({required this.type, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s8, vertical: EmSpacing.s4),
        decoration: const BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.pillAll),
        child: CalendarTypeLabel(color: color, label: type.label, dotSize: 8),
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
      padding: const EdgeInsets.symmetric(vertical: EmSpacing.s8),
      child: Wrap(spacing: EmSpacing.s12, runSpacing: EmSpacing.s4, children: [
        for (final t in list)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
            const SizedBox(width: EmSpacing.s4 + EmSpacing.s2),
            Text(t.label, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w600)),
          ]),
      ]),
    );
  }
}
