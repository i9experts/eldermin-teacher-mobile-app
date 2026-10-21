import '../design/design.dart';
import 'package:flutter/material.dart';

class AppTag extends StatelessWidget {
  final String label;
  final EmTone style;
  const AppTag(this.label, {super.key, this.style = EmTone.info});

  /// Status pill: tone container + dark text (AA), caption size so it stays readable at large text scales.
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: style.background, borderRadius: EmRadius.pillAll),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s4),
        child: Text(label, style: EmType.caption.copyWith(color: style.foreground, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
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
  const AppProgressBar({super.key, required this.percent, this.color = EmColors.primary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: EmRadius.pillAll,
      child: SizedBox(
        height: EmSpacing.s8,
        child: LinearProgressIndicator(
          value: percent.clamp(0, 100) / 100,
          backgroundColor: EmColors.primaryLight,
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
  const ListCardRow({super.key, required this.icon, this.iconColor = EmColors.primary, required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor.withAlpha(26), borderRadius: EmRadius.smAll),
            child: ExcludeSemantics(child: Icon(icon, color: iconColor, size: 20)),
          ),
          const SizedBox(width: EmSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.label.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
                    if (trailing != null) ...[const SizedBox(width: EmSpacing.s8), trailing!],
                  ],
                ),
                const SizedBox(height: EmSpacing.s4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});
  @override
  Widget build(BuildContext context) => const EmLoading();
}
