import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../tokens/em_colors.dart';

/// Page dots for the onboarding photos: the active dot is an accent pill that
/// follows [progress] (the PageController offset), the others are light dots.
class EmPhotoDots extends StatelessWidget {
  const EmPhotoDots({super.key, required this.count, required this.progress});
  final int count;
  final ValueListenable<double> progress;

  static const double dot = 8, activeWidth = 24, gap = 8;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, p, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Container(
                width: dot + (activeWidth - dot) * activeness(i, p),
                height: dot,
                decoration: BoxDecoration(
                  color: Color.lerp(EmColors.primaryLight.withAlpha(140), EmColors.accent, activeness(i, p)),
                  borderRadius: BorderRadius.circular(dot),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 1 on dot [i]'s own page, falling to 0 a page away.
  static double activeness(int i, double progress) => math.max(0.0, 1 - (progress - i).abs());
}
