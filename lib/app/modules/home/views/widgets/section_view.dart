import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../models/section_state.dart';

/// Renders one independent Home section from its [SectionState]:
/// shimmer while loading, [builder] with data, an empty message, or an
/// error card with Retry. 403 hides the section (all Home sections are
/// permission-gated) unless [hideWhenForbidden] is false; 404/501 hides it
/// when [hideWhenUnavailable] (feature not deployed yet).
class SectionView<T> extends StatelessWidget {
  final String title;
  final SectionState<T> state;
  final Widget Function(T data) builder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final VoidCallback onRetry;
  final bool hideWhenForbidden;
  final bool hideWhenUnavailable;
  final int skeletonRows;
  final VoidCallback? onSeeAll;

  const SectionView({
    super.key,
    required this.title,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here',
    this.emptySubtitle,
    this.hideWhenForbidden = true,
    this.hideWhenUnavailable = false,
    this.skeletonRows = 2,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status == SectionStatus.forbidden && hideWhenForbidden) return const SizedBox.shrink();
    if (state.status == SectionStatus.unavailable && hideWhenUnavailable) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionRow(title: title, onSeeAll: state.hasData ? onSeeAll : null),
        _body(),
        const SizedBox(height: EmSpacing.s4),
      ],
    );
  }

  Widget _iconChip(IconData icon, {Color bg = EmColors.primaryTint, Color fg = EmColors.primary}) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: ExcludeSemantics(child: Icon(icon, color: fg, size: 22)),
      );

  Widget _body() {
    switch (state.status) {
      case SectionStatus.loading:
        return EmShimmer(
          key: const Key('section_loading'),
          child: Column(children: List.generate(skeletonRows, (_) => const EmSkeletonRow())),
        );
      case SectionStatus.data:
        return builder(state.data as T);
      case SectionStatus.empty:
        return EmCard(
          key: const Key('section_empty'),
          child: Row(children: [
            _iconChip(emptyIcon),
            const SizedBox(width: EmSpacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(emptyTitle, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
                if (emptySubtitle != null) Text(emptySubtitle!, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13)),
              ]),
            ),
          ]),
        );
      case SectionStatus.forbidden:
        return EmCard(
          key: const Key('section_forbidden'),
          child: Row(children: [
            _iconChip(Icons.lock_outline_rounded, bg: EmColors.primaryTint, fg: EmColors.textSecondary),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text("You don't have access", style: EmType.body.copyWith(color: EmColors.textSecondary))),
          ]),
        );
      case SectionStatus.unavailable:
        return EmCard(
          key: const Key('section_unavailable'),
          child: Row(children: [
            _iconChip(Icons.cloud_off_outlined, bg: EmColors.primaryTint, fg: EmColors.textSecondary),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text('Not available on this server yet', style: EmType.body.copyWith(color: EmColors.textSecondary))),
          ]),
        );
      case SectionStatus.error:
        if (state.isStale) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RefreshFailedBanner(message: state.message, onRetry: onRetry),
            builder(state.data as T),
          ]);
        }
        return EmCard(
          key: const Key('section_error'),
          child: Row(children: [
            _iconChip(Icons.error_outline_rounded, bg: EmColors.errorContainer, fg: EmColors.onErrorContainer),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text(state.message ?? 'Something went wrong', maxLines: 3, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.textSecondary))),
            TextButton(onPressed: onRetry, child: Text('Retry', style: EmType.label.copyWith(color: EmColors.primary))),
          ]),
        );
    }
  }
}
