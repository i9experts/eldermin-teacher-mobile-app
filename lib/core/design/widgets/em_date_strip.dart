import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

/// Horizontal strip of vertical day pills. Selected = solid primary with a
/// white inner circle; others white. Pills are 48dp wide (touch target), so
/// the strip scrolls when 7 do not fit, keeping the selected day in view.
class EmDateStrip extends StatefulWidget {
  const EmDateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.markedDays = const {},
  });

  /// Consecutive days to show (typically 7).
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Days that get a small dot under the number (events).
  final Set<DateTime> markedDays;

  /// The 7 days of the week containing [anchor], starting Monday.
  static List<DateTime> weekOf(DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
    return [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
  }

  @override
  State<EmDateStrip> createState() => _EmDateStripState();
}

bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _EmDateStripState extends State<EmDateStrip> {
  final _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(covariant EmDateStrip old) {
    super.didUpdateWidget(old);
    if (!_same(old.selected, widget.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selectedKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: EmMotion.normal);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final height = 76.0 * scale;
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        const minPill = 48.0, gap = 6.0;
        final fits = c.maxWidth >= widget.days.length * minPill + (widget.days.length - 1) * gap;
        final pills = [
          for (final d in widget.days)
            _DayPill(
              key: _same(d, widget.selected) ? _selectedKey : null,
              day: d,
              selected: _same(d, widget.selected),
              marked: widget.markedDays.any((m) => _same(m, d)),
              onTap: () => widget.onSelected(d),
            ),
        ];
        if (fits) {
          return Row(children: [
            for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(width: gap), Expanded(child: pills[i])],
          ]);
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pills.length,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (_, i) => SizedBox(width: minPill, child: pills[i]),
        );
      }),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({super.key, required this.day, required this.selected, required this.marked, required this.onTap});
  final DateTime day;
  final bool selected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEE').format(day);
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat('EEEE d MMMM').format(day),
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: EmMotion.normal,
        decoration: BoxDecoration(color: selected ? EmColors.primary : EmColors.surface, borderRadius: EmRadius.pillAll),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: EmRadius.pillAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(label, maxLines: 1, style: EmType.caption.copyWith(color: selected ? EmColors.onPrimary : EmColors.ink)),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? EmColors.surface : Colors.transparent),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text('${day.day}', style: EmType.label.copyWith(color: selected ? EmColors.primary : EmColors.ink)),
                      ),
                    ),
                  ),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: marked ? (selected ? EmColors.onPrimary : EmColors.primary) : Colors.transparent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
