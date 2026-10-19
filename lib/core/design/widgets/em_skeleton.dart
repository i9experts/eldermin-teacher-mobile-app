import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';

/// Shimmer wrapper in the design tokens. Wrap one or more skeleton shapes.
class EmShimmer extends StatelessWidget {
  const EmShimmer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Shimmer.fromColors(baseColor: EmColors.shimmerBase, highlightColor: EmColors.shimmerHighlight, child: child),
      );
}

/// A plain rounded block for skeletons.
class EmSkeletonBox extends StatelessWidget {
  const EmSkeletonBox({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
        width: circle ? height : width,
        height: height,
        decoration: BoxDecoration(color: EmColors.surface, shape: circle ? BoxShape.circle : BoxShape.rectangle, borderRadius: circle ? null : BorderRadius.circular(radius)),
      );
}

/// Loading placeholder for an [EmListRow]-shaped card (leading circle + two lines).
class EmSkeletonRow extends StatelessWidget {
  const EmSkeletonRow({super.key, this.compact = false});

  /// Shorter row (pickers and sheets, where five of them must fit a small panel).
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsetsDirectional.only(bottom: compact ? 8 : 12),
        padding: EdgeInsetsDirectional.all(compact ? 12 : 16),
        decoration: const BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.cardAll),
        child: Row(children: [
          EmSkeletonBox(height: compact ? 36 : 44, circle: true),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              EmSkeletonBox(height: 14, width: 160),
              SizedBox(height: 8),
              EmSkeletonBox(height: 12, width: 100),
            ]),
          ),
        ]),
      );
}
