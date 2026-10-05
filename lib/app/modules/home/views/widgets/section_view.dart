import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../../core/widgets/shimmer_widgets.dart';
import '../../../../components/custom_text.dart';
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
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _body() {
    switch (state.status) {
      case SectionStatus.loading:
        return AppShimmer(
          key: const Key('section_loading'),
          child: Column(children: List.generate(skeletonRows, (_) => const ShimmerListRowSkeleton())),
        );
      case SectionStatus.data:
        return builder(state.data as T);
      case SectionStatus.empty:
        return AppCard(
          key: const Key('section_empty'),
          child: Row(children: [
            Icon(emptyIcon, color: AppColors.faint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CustomText(text: emptyTitle, fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 13),
                if (emptySubtitle != null)
                  CustomText(text: emptySubtitle!, color: AppColors.faint, fontSize: 11),
              ]),
            ),
          ]),
        );
      case SectionStatus.forbidden:
        return const AppCard(
          key: Key('section_forbidden'),
          child: CustomText(text: "You don't have access", color: AppColors.muted, fontSize: 12),
        );
      case SectionStatus.unavailable:
        return const AppCard(
          key: Key('section_unavailable'),
          child: CustomText(text: 'Not available on this server yet', color: AppColors.muted, fontSize: 12),
        );
      case SectionStatus.error:
        return AppCard(
          key: const Key('section_error'),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 22),
            const SizedBox(width: 12),
            Expanded(child: CustomText(text: state.message ?? 'Something went wrong', color: AppColors.muted, fontSize: 12, maxLines: 3)),
            TextButton(onPressed: onRetry, child: const CustomText(text: 'Retry', color: AppColors.blue, fontWeight: FontWeight.w700)),
          ]),
        );
    }
  }
}
