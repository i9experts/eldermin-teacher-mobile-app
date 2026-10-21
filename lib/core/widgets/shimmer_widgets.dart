import '../design/design.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
      baseColor: EmColors.shimmerBase,
      highlightColor: EmColors.shimmerHighlight,
      child: child,
    );
  }
}

/// Mirrors [ListCardRow] / [AppCard] - the workhorse for every list screen:
/// an icon-circle bone + a two-line text bone.
class ShimmerListRowSkeleton extends StatelessWidget {
  const ShimmerListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const EmSkeletonRow(compact: true);
}

/// Convenience: N [ShimmerListRowSkeleton]s in a row of their own.
List<Widget> shimmerListRows([int count = 6]) =>
    List.generate(count, (_) => const ShimmerListRowSkeleton());
