import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'em_colors.dart';

/// Tokens of the navy overlay that sits on every auth photo, and the rule that
/// keeps text legible on it (MOTION_SPEC.md section 7).
///
/// The overlay is [base] at an alpha that rises from 0 (clear photo) to
/// [bottomAlpha] (near-opaque) down the backdrop. Its stops hang off [safeTop]:
///
///   safeTop - [rampLength]  alpha 0
///   safeTop                 alpha [midAlpha]
///   safeTop + [strongOffset] alpha [strongAlpha]   <- the "strong line"
///   1.0                     alpha [bottomAlpha]
///
/// RULE: text only starts at or below the strong line. The photo under it is
/// unknown, so legibility is measured against the WORST case: the overlay's
/// guaranteed alpha at that line composited over pure white ([worstCaseAt]).
/// White, muted-light and large accent text are AA on that colour; small accent
/// text never is (accent on the brand navy is 4.43:1), so accent text is always
/// large / bold.
class EmPhotoOverlay {
  EmPhotoOverlay._();

  static const Color base = EmColors.primaryDark;

  /// Distance (fraction of the backdrop height) over which the overlay builds up.
  static const double rampLength = 0.34;

  static const double midAlpha = 0.75;
  static const double strongAlpha = 0.90;
  static const double strongOffset = 0.08;
  static const double bottomAlpha = 0.98;

  /// Where the strong line sits when a screen has no content to measure.
  static const double defaultSafeTop = 0.60;

  /// Navy scrim under the status bar so its light icons read on a bright photo.
  static const double topScrimAlpha = 0.35;
  static const double topScrimHeight = 120;

  /// [safeTop] that puts the strong line [margin] above [contentTop] (both fractions of the backdrop height).
  static double safeTopFor(double contentTop, {double margin = 0.0}) =>
      (contentTop - strongOffset - margin).clamp(0.0, 1.0 - strongOffset).toDouble();

  /// Strong line (fraction of the backdrop height) for a [safeTop].
  static double strongLine(double safeTop) => math.min(1.0, safeTop + strongOffset);

  /// Gradient stops (position, alpha) for a [safeTop].
  static List<({double at, double alpha})> stops(double safeTop, {double bottom = bottomAlpha}) {
    final s = safeTop.clamp(0.0, 1.0 - strongOffset).toDouble();
    return [
      (at: 0, alpha: 0),
      (at: math.max(0.0, s - rampLength), alpha: 0),
      (at: s, alpha: midAlpha),
      (at: s + strongOffset, alpha: strongAlpha),
      (at: 1, alpha: bottom),
    ];
  }

  /// The guaranteed overlay alpha at [y] (fraction of the backdrop height).
  static double alphaAt(double y, {double safeTop = defaultSafeTop, double bottom = bottomAlpha}) {
    final st = stops(safeTop, bottom: bottom);
    if (y <= st.first.at) return st.first.alpha;
    for (var i = 1; i < st.length; i++) {
      if (y <= st[i].at) {
        final a = st[i - 1], b = st[i];
        if (b.at == a.at) return b.alpha;
        return a.alpha + (b.alpha - a.alpha) * (y - a.at) / (b.at - a.at);
      }
    }
    return st.last.alpha;
  }

  /// The lightest colour the overlay can be at [y]: [base] at the guaranteed
  /// alpha over pure white. Text contrast is measured against this.
  static Color worstCaseAt(double y, {double safeTop = defaultSafeTop, double bottom = bottomAlpha}) =>
      Color.alphaBlend(base.withValues(alpha: alphaAt(y, safeTop: safeTop, bottom: bottom)), const Color(0xFFFFFFFF));

  /// The worst-case background at the strong line: what every text colour on a photo is checked against.
  static Color get worstCaseAtStrongLine => worstCaseAt(strongLine(defaultSafeTop));

  /// Every text / UI colour allowed on the overlay, with the ratio it must reach
  /// on [worstCaseAtStrongLine]. Checked by test/design/photo_overlay_contrast_test.dart.
  static const List<EmOverlayPair> pairs = [
    EmOverlayPair('white title / body', EmColors.onPrimaryDark, 4.5),
    EmOverlayPair('muted light body (primaryContainer)', EmColors.primaryContainer, 4.5),
    EmOverlayPair('caption (primaryLight)', EmColors.primaryLight, 4.5),
    EmOverlayPair('accent LARGE bold text', EmColors.accent, 3.0),
    EmOverlayPair('light field border (primaryLight)', EmColors.primaryLight, 3.0),
    EmOverlayPair('active dot (accent)', EmColors.accent, 3.0),
  ];
}

class EmOverlayPair {
  final String name;
  final Color foreground;
  final double min;
  const EmOverlayPair(this.name, this.foreground, this.min);
}
