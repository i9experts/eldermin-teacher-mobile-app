import '../design/design.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../app/components/custom_text.dart';

class AppTag extends StatelessWidget {
  final String label;
  final TagStyle style;
  const AppTag(this.label, {super.key, this.style = TagStyle.info});

  /// Status pill: tone container + dark text (AA), caption size so it stays readable at large text scales.
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: style.bg, borderRadius: EmRadius.pillAll),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s4),
        child: Text(label, style: EmType.caption.copyWith(color: style.fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = EmSpacing.cardPad, this.margin = const EdgeInsets.only(bottom: EmSpacing.row), this.onTap});

  @override
  Widget build(BuildContext context) => Padding(padding: margin, child: EmCard(padding: padding, onTap: onTap, child: child));
}

class StatsRow extends StatelessWidget {
  final List<(String value, String label, String? trend)> items;

  /// Optional tap handler per item (same order); a null entry = not tappable.
  final List<VoidCallback?>? onTaps;
  const StatsRow({super.key, required this.items, this.onTaps});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: EmSpacing.s8),
            Expanded(
              child: EmCard(
                key: onTaps != null && i < onTaps!.length && onTaps![i] != null ? ValueKey('stat_tap_$i') : null,
                padding: EmSpacing.cardPadCompact,
                radius: EmRadius.tile,
                onTap: onTaps != null && i < onTaps!.length ? onTaps![i] : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.value.copyWith(color: EmColors.ink)),
                  const SizedBox(height: EmSpacing.s2),
                  Text(item.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                  if (item.$3 != null) ...[
                    const SizedBox(height: EmSpacing.s2),
                    Text(item.$3!, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.primary)),
                  ],
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  final int percent;
  final Color color;
  const AppProgressBar({super.key, required this.percent, this.color = AppColors.blue});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 7,
        child: LinearProgressIndicator(
          value: percent.clamp(0, 100) / 100,
          backgroundColor: const Color(0xFFEAF0F4),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

class ListCardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const ListCardRow({super.key, required this.icon, this.iconColor = AppColors.blue, required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: CustomText(text: title, fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                  ],
                ),
                const SizedBox(height: 3),
                CustomText(text: subtitle, color: AppColors.muted, fontSize: 9.5, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppTimeline extends StatelessWidget {
  final List<(String time, String title, String meta, Color dotColor)> items;
  const AppTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: e.value.$4, border: Border.all(color: const Color(0xFFDCEDF8), width: 3))),
                    if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFDCE7EF))),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(text: e.value.$1, color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700),
                      const SizedBox(height: 2),
                      CustomText(text: e.value.$2, color: AppColors.primaryColor, fontSize: 11, fontWeight: FontWeight.w700),
                      CustomText(text: e.value.$3, color: AppColors.muted, fontSize: 9),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const SegmentedControl({super.key, required this.options, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) => EmSegmentedTabs<int>(
        segments: [for (final (i, o) in options.indexed) EmSegment(i, o)],
        selected: selectedIndex,
        onChanged: onChanged,
      );
}

class DateStripWidget extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selected;
  final Set<DateTime> highlighted;
  final ValueChanged<DateTime> onSelect;
  const DateStripWidget({super.key, required this.days, required this.selected, this.highlighted = const {}, required this.onSelect});

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [BoxShadow(color: AppColors.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: days.map((d) {
          final isSelected = _isSameDay(d, selected);
          final hasEvent = highlighted.any((h) => _isSameDay(h, d));
          return Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelect(d),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: isSelected ? AppColors.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      CustomText(text: _dayLetters[(d.weekday - 1) % 7], color: isSelected ? const Color(0xFFBFD8ED) : AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700),
                      const SizedBox(height: 4),
                      CustomText(text: '${d.day}', color: isSelected ? Colors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700),
                      if (hasEvent && !isSelected) Container(margin: const EdgeInsets.only(top: 3), width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DonutRing extends StatelessWidget {
  final int percent;
  final Color color;
  final double size;
  const DonutRing({super.key, required this.percent, this.color = AppColors.blue, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _DonutPainter(percent: percent, color: color)),
          CustomText(text: '$percent%', color: AppColors.primaryColor, fontSize: 18, fontWeight: FontWeight.w800),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int percent;
  final Color color;
  _DonutPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final bgPaint = Paint()..color = const Color(0xFFEAF0F4)..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()..color = color..style = PaintingStyle.fill;
    final sweep = 2 * 3.14159265 * (percent.clamp(0, 100) / 100);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -3.14159265 / 2, sweep, false)
      ..close();
    canvas.drawPath(path, fgPaint);

    canvas.drawCircle(center, radius - 10, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.percent != percent || oldDelegate.color != color;
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});
  @override
  Widget build(BuildContext context) => const EmLoading();
}

/// Error body with Retry ("Try again"): the [message] only, no extra title (Em look, shrink-wrapped
/// so it also works inside a list).
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => EmErrorState(title: null, message: message, onRetry: onRetry, retryLabel: 'Try again', scroll: false, compact: true);
}

/// Shown ABOVE the last good data when a refresh failed ("Refresh failed - Retry"); the data stays on screen.
/// A failed first load uses [AppErrorView] / the section error card instead.
class RefreshFailedBanner extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const RefreshFailedBanner({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('refresh_failed_banner'),
        margin: const EdgeInsetsDirectional.only(bottom: EmSpacing.s12),
        padding: const EdgeInsetsDirectional.only(start: EmSpacing.s16, top: EmSpacing.s4, bottom: EmSpacing.s4, end: EmSpacing.s4),
        decoration: const BoxDecoration(color: EmColors.errorContainer, borderRadius: EmRadius.mdAll),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: EmColors.onErrorContainer, size: 20),
          const SizedBox(width: EmSpacing.s8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Refresh failed', style: EmType.label.copyWith(color: EmColors.onErrorContainer)),
              if (message != null) Text(message!, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.onErrorContainer, fontWeight: FontWeight.w400)),
            ]),
          ),
          TextButton(onPressed: onRetry, child: Text('Retry', style: EmType.label.copyWith(color: EmColors.primary))),
        ]),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const AppEmptyView({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => EmEmptyState(icon: icon, title: title, message: subtitle, scroll: false, compact: true);
}

class SectionRow extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionRow({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: EmSpacing.s16, bottom: EmSpacing.s8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)),
          ),
        ),
        if (onSeeAll != null)
          Semantics(
            button: true,
            label: 'See all $title',
            excludeSemantics: true,
            onTap: onSeeAll,
            child: InkWell(
              onTap: onSeeAll,
              borderRadius: EmRadius.smAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s8),
                    child: Text('See all', style: EmType.label.copyWith(color: EmColors.primary)),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Matches the mockup's `.screen-head` — the big in-body title + caption
/// that appears at the top of every screen's scrollable content (distinct
/// from the Scaffold's own AppBar, which the mockup doesn't have per-screen
/// at all since its single persistent top bar only shows the avatar and
/// notification bell).
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final String? selectLabel;
  final VoidCallback? onSelectTap;
  const ScreenHeader({super.key, required this.title, this.caption, this.selectLabel, this.onSelectTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(text: title, fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.primaryColor, letterSpacing: -0.75, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (caption != null) ...[
                  const SizedBox(height: 5),
                  CustomText(text: caption!, fontSize: 11, color: AppColors.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (selectLabel != null) ...[
            const SizedBox(width: 10),
            if (onSelectTap != null)
              // A real, working selector (a callback is wired) — styled as
              // an interactive pill with a chevron affordance.
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: onSelectTap,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CustomText(text: selectLabel!, fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                      const Icon(Icons.expand_more_rounded, size: 14, color: AppColors.primaryColor),
                    ]),
                  ),
                ),
              )
            else
              // No callback wired — this is informational context, not a
              // control. Rendered as a plain tinted badge (no chevron, no
              // tap ripple) so it never reads as a broken/dead dropdown.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(11)),
                child: CustomText(text: selectLabel!, fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
              ),
          ],
        ],
      ),
    );
  }
}

/// Matches the mockup's `.date-strip` / `dateStrip()` — a self-contained
/// current-week strip that manages its own selected day, so screens can
/// drop it in with zero controller plumbing (the mockup's own date chips
/// aren't wired to real data filtering either, just a toast).
class AppWeekDateStrip extends StatefulWidget {
  final Set<DateTime> highlighted;
  final ValueChanged<DateTime>? onSelect;
  const AppWeekDateStrip({super.key, this.highlighted = const {}, this.onSelect});

  @override
  State<AppWeekDateStrip> createState() => _AppWeekDateStripState();
}

class _AppWeekDateStripState extends State<AppWeekDateStrip> {
  late DateTime _selected;
  late List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _days = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return DateStripWidget(
      days: _days,
      selected: _selected,
      highlighted: widget.highlighted,
      onSelect: (d) {
        setState(() => _selected = d);
        widget.onSelect?.call(d);
      },
    );
  }
}
