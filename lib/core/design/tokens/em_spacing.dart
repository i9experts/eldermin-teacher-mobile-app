import 'package:flutter/painting.dart';

/// 4-based spacing scale.
class EmSpacing {
  EmSpacing._();
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Horizontal screen padding (REFERENCE_SPEC: 20-24).
  static const double screenH = 20;

  /// Gap between major blocks (16-20) and between list rows (12).
  static const double block = 16;
  static const double row = 12;

  /// Minimum touch target.
  static const double minTouch = 48;

  /// Bottom padding to clear the nav bar + diamond FAB overlap.
  static const double navClearance = 104;

  /// Bottom padding of a list that has a floating action button.
  static const double fabClearance = 96;

  /// Standard scroll-view insets for a screen body under the app bar.
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(screenH, s16, screenH, s24);
  static const EdgeInsets listPaddingFab = EdgeInsets.fromLTRB(screenH, s16, screenH, fabClearance);

  /// Margin of a floating snackbar that must sit above a screen's own bottom bar (so it never covers the buttons).
  static const EdgeInsets snackAboveBar = EdgeInsets.fromLTRB(s16, 0, s16, 170);

  /// Inner padding of a card, of a compact row and of a chip-like control.
  static const EdgeInsets cardPad = EdgeInsets.all(s16);
  static const EdgeInsets cardPadCompact = EdgeInsets.all(s12);
  static const EdgeInsets chipPad = EdgeInsets.symmetric(horizontal: s16, vertical: s8);
}
