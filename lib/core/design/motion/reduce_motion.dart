import 'package:flutter/widgets.dart';
import '../tokens/em_motion.dart';

/// Reduce-motion policy for the auth motion language.
///
/// [MediaQuery.disableAnimationsOf] is Flutter's mapping of iOS "Reduce
/// Motion" and Android "Remove animations" (animator duration scale 0). When it
/// is on, nothing drifts, ripples or flies: state changes are crossfades
/// ([EmMotion.crossfade]) only.
class EmReduceMotion {
  EmReduceMotion._();

  static bool of(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// [full] normally, [EmMotion.crossfade] (or zero) when reduced.
  static Duration duration(BuildContext context, Duration full, {bool crossfadeOnly = true}) =>
      of(context) ? (crossfadeOnly ? EmMotion.crossfade : Duration.zero) : full;
}

/// [AnimatedSize] that is simply [child] with reduce motion on (an
/// [AnimatedSize] with a zero duration asserts when its child changes size).
class EmAnimatedSize extends StatelessWidget {
  const EmAnimatedSize({super.key, required this.child, this.duration = EmMotion.slow, this.curve = EmMotion.enter, this.alignment = Alignment.topCenter});
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (EmReduceMotion.of(context)) return child;
    return AnimatedSize(duration: duration, curve: curve, alignment: alignment, child: child);
  }
}
