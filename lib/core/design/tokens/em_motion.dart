import 'package:flutter/animation.dart';

/// Motion tokens. The auth motion language ("Connected Nodes") is specified in
/// eldermin-teacher-app-docs/design/MOTION_SPEC.md.
class EmMotion {
  EmMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration chart = Duration(milliseconds: 600);

  /// Content entrances (card rise, fields).
  static const Duration emphasis = Duration(milliseconds: 480);

  /// Logo hand-off flight between screens.
  static const Duration hero = Duration(milliseconds: 560);

  /// Replacement for every motion when reduce-motion is on.
  static const Duration crossfade = Duration(milliseconds: 200);

  /// The splash photo + logo tile reveal (inside the first motion beat, 700 ms).
  static const Duration photoReveal = Duration(milliseconds: 600);

  /// One cycle of the two accent rings that ripple out of the splash logo tile.
  static const Duration ringPeriod = Duration(milliseconds: 2200);

  /// How long the sign-in screen stays up after a success, so the drawn check is seen.
  static const Duration successHold = Duration(milliseconds: 700);

  /// Delay between staggered entrances (fields, list items).
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration staggerTight = Duration(milliseconds: 40);

  /// One dash-offset cycle of the logomark's dashed links.
  static const Duration dashPeriod = Duration(milliseconds: 1000);

  /// Ambient (constellation) loop. Node drift uses whole cycles per loop so it
  /// never seams.
  static const Duration ambientPeriod = Duration(seconds: 60);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve pulse = Curves.easeInOut;

  // ---- Distances (dp) ----
  static const double riseDistance = 24;
  static const double shakeDistance = 8;
  static const double driftMin = 4;
  static const double driftMax = 10;

  /// Onboarding parallax: a photo trails the swipe by this much per page, and is
  /// scaled up by [parallaxScale] so its edge never shows.
  static const double parallaxShift = 24;
  static const double parallaxScale = 1.14;
}
