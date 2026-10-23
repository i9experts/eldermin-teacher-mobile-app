import '../tokens/em_motion.dart';

/// Timeline of the animated splash (see MOTION_SPEC.md §3.1). All numbers
/// here; the painter shapes the sweeps inside these windows.
class EmSplashTimeline {
  EmSplashTimeline._();

  /// Intro motion, from the first Flutter frame.
  static const Duration intro = Duration(milliseconds: 1500);

  /// Shortest the splash is held while init runs: one motion beat (link charge
  /// plus the start of the pulse). Slower init just keeps the motion looping.
  static const Duration minHold = Duration(milliseconds: 950);

  /// Init still pending after this long: a small "Connecting…" caption fades in.
  static const Duration slowInitAfter = Duration(seconds: 3);

  // Windows inside [intro], in ms.
  static const ({int begin, int end}) charge = (begin: 40, end: 790);
  static const ({int begin, int end}) pulse = (begin: 680, end: 1300);
  static const ({int begin, int end}) ripple = (begin: 680, end: 1440);
  static const ({int begin, int end}) text = (begin: 120, end: 520);

  /// End of each motion beat: B1 charge, B2 pulse, B3 settle. After the last
  /// one there are no beats and the exit may start at once.
  static const List<int> beatEnds = [700, 1300, 1500];

  /// Hard cap on the motion that runs after init completes (exit included).
  static const Duration maxAfterInit = Duration(milliseconds: 1600);

  /// How long to wait, after init completed at [elapsed] since the first frame,
  /// before starting the exit: the rest of the current beat, never more than
  /// [maxAfterInit] minus the exit itself.
  static Duration exitDelay(Duration elapsed, {Duration exit = EmMotion.hero}) {
    final ms = elapsed.inMilliseconds;
    var wait = 0;
    for (final end in beatEnds) {
      if (ms < end) {
        wait = end - ms;
        break;
      }
    }
    final cap = (maxAfterInit - exit).inMilliseconds;
    return Duration(milliseconds: wait < cap ? wait : cap);
  }

  /// Fraction of [intro] for a window edge.
  static double at(int ms) => ms / intro.inMilliseconds;
}
