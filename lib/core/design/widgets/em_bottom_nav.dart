import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_shadows.dart';
import '../tokens/em_typography.dart';

class EmNavItem {
  const EmNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.badgeCapped = false,
    this.badgeKey,
    this.showDot = false,
  });
  final IconData icon;

  /// Filled variant shown when active.
  final IconData activeIcon;
  final String label;

  /// Unread count over the icon (null/0 = none; >99 shows "99+").
  final int? badgeCount;

  /// The count is a lower bound (shows "n+").
  final bool badgeCapped;

  /// Key set on the count badge (tests / finders).
  final Key? badgeKey;
  final bool showDot;
}

/// White bar, top radius 32: two items | centre slot | two items. The optional
/// [centerAction] (an [EmDiamondFab]) overlaps the top edge by half. Active
/// item = filled icon + primary label; no pill behind it.
///
/// Without a [centerAction] the four items share the full width (no gap). It
/// is the app shell's bottom navigation (`HomeShell`, key `app_shell_nav`).
/// The widget's own height includes the FAB overhang, so a scaffold body with
/// `extendBody: false` ends above it.
class EmBottomNav extends StatelessWidget {
  const EmBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap, this.centerAction})
      : assert(items.length == 4, 'EmBottomNav shows exactly 4 items plus the centre slot');

  final List<EmNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget? centerAction;

  static const double barHeight = 68;
  static const double overhang = 30;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();
    final h = barHeight + (scale - 1) * 24;
    Widget item(int i) => Expanded(child: _NavButton(item: items[i], active: i == currentIndex, index: i, total: items.length, onTap: () => onTap(i)));
    return SizedBox(
      height: h + overhang + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h + bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: EmColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(EmRadius.navTop)),
                boxShadow: EmShadows.nav,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom, left: 8, right: 8),
                  child: Row(children: [item(0), item(1), if (centerAction != null) const SizedBox(width: 84), item(2), item(3)]),
                ),
              ),
            ),
          ),
          if (centerAction != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: SizedBox(height: overhang + 44, child: Align(alignment: Alignment.topCenter, child: centerAction))),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.index, required this.total, required this.onTap});
  final EmNavItem item;
  final bool active;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? EmColors.primary : EmColors.textSecondary;
    final n = item.badgeCount ?? 0;
    Widget icon = Icon(active ? item.activeIcon : item.icon, size: 24, color: color);
    if (n > 0 || item.showDot) {
      icon = Stack(clipBehavior: Clip.none, children: [
        icon,
        PositionedDirectional(
          top: -4,
          end: n > 0 ? -10 : -2,
          child: n > 0
              ? Container(
                  key: item.badgeKey ?? const Key('em_nav_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: const BoxDecoration(color: EmColors.error, borderRadius: EmRadius.pillAll),
                  child: Text(n > 99 ? '99+' : '$n${item.badgeCapped ? '+' : ''}', style: EmType.navLabel.copyWith(color: EmColors.onError, fontSize: 10, height: 1.2)),
                )
              : Container(key: const Key('em_nav_dot'), width: 9, height: 9, decoration: BoxDecoration(color: EmColors.error, shape: BoxShape.circle, border: Border.all(color: EmColors.surface, width: 1.5))),
        ),
      ]);
    }
    return Semantics(
      button: true,
      selected: active,
      label: '${item.label}, tab ${index + 1} of $total${n > 0 ? ', $n unread' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.navLabel.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
