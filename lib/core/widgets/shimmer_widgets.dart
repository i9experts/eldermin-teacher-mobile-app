import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart' show AppRadius, AppSpacing, AppColors;
// import '../../app/config/app_colors.dart' show AppColors;

/// Wraps a skeleton layout in the shimmer sweep animation. Wrap once per
/// screen around the whole loading-state layout below, not around each
/// individual bone - one [Shimmer.fromColors] driving many bones is both
/// cheaper and keeps the sweep synchronized across the screen.
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: child,
    );
  }
}

/// The basic "line" placeholder bone.
class ShimmerBone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const ShimmerBone({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: AppColors.shimmerShape,
          borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// A circular bone - icon badges, avatars.
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            color: AppColors.shimmerShapeAlt, shape: BoxShape.circle));
  }
}

/// Mirrors [ScreenHeader] - title + caption + optional trailing chip.
class ShimmerScreenHeaderSkeleton extends StatelessWidget {
  final bool withChip;
  const ShimmerScreenHeaderSkeleton({super.key, this.withChip = true});

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
              children: const [
                ShimmerBone(width: 160, height: 22, radius: 6),
                SizedBox(height: 8),
                ShimmerBone(width: 210, height: 12, radius: 5),
              ],
            ),
          ),
          if (withChip) ...[
            const SizedBox(width: 10),
            const ShimmerBone(width: 78, height: 32, radius: 11),
          ],
        ],
      ),
    );
  }
}

/// Mirrors [DateStripWidget] / [AppWeekDateStrip] - 7 equal day boxes.
class ShimmerDateStripSkeleton extends StatelessWidget {
  const ShimmerDateStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.shimmerBase)),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Container(
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                  color: AppColors.shimmerShape,
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }),
      ),
    );
  }
}

/// Mirrors [StatsRow] - N equal stat tiles, each a value bone + label bone.
class ShimmerStatsRowSkeleton extends StatelessWidget {
  final int count;
  const ShimmerStatsRowSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isLast = i == count - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.shimmerBase)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 30, height: 16, radius: 5),
                SizedBox(height: 6),
                ShimmerBone(width: 44, height: 8, radius: 4),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Mirrors [HeroCard] - a single rounded block at the same height/radius
/// as the real navy gradient card, since a gradient can't shimmer cleanly.
class ShimmerHeroCardSkeleton extends StatelessWidget {
  const ShimmerHeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.shimmerShape,
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 100, height: 10, radius: 4),
                SizedBox(height: 10),
                ShimmerBone(width: 70, height: 26, radius: 6),
                SizedBox(height: 8),
                ShimmerBone(width: 140, height: 10, radius: 4),
              ],
            ),
          ),
          ShimmerCircle(size: 76),
        ],
      ),
    );
  }
}

/// Mirrors the `AppCard`-wrapped chart cards (`AppBarChart`/`AppLineChart`)
/// - a title bone above a full-width chart-shaped rectangle.
class ShimmerChartSkeleton extends StatelessWidget {
  const ShimmerChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.shimmerBase)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(width: 90, height: 12, radius: 5),
          SizedBox(height: 12),
          ShimmerBone(width: double.infinity, height: 90, radius: 10),
        ],
      ),
    );
  }
}

/// Mirrors [ListCardRow] / [AppCard] - the workhorse for every list screen:
/// an icon-circle bone + a two-line text bone.
class ShimmerListRowSkeleton extends StatelessWidget {
  const ShimmerListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.shimmerBase)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerCircle(size: 38),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 130, height: 12, radius: 5),
                SizedBox(height: 6),
                ShimmerBone(width: 90, height: 9, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience: N [ShimmerListRowSkeleton]s in a row of their own.
List<Widget> shimmerListRows([int count = 6]) =>
    List.generate(count, (_) => const ShimmerListRowSkeleton());
