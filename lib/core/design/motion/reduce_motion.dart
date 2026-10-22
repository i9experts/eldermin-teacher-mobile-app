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
