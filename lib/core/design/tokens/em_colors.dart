import 'package:flutter/material.dart';

/// Eldermin colour tokens.
///
/// Brand hexes are PIXEL-SAMPLED from `assets/images/eldermin_logomark.png`
/// (D0 audit) and are PENDING BRAND CONFIRMATION. Change them here only.
///
/// Accent ([accent]) is for fills and icons only - never text. Glyphs on an
/// accent fill use [onAccent] (navy).
class EmColors {
  EmColors._();

  // ---- Brand (pending brand confirmation) ----
  static const Color primaryDark = Color(0xFF18457A);
  static const Color primary = Color(0xFF1B5FA3);
  static const Color primaryMid = Color(0xFF4A89C8);
  static const Color primaryLight = Color(0xFFB5D3EC);
  static const Color primaryContainer = Color(0xFFDCEAF7);

  /// Lighter nested tile inside a [primaryContainer] hero (stat tiles).
  static const Color primaryTint = Color(0xFFE9F1FA);
  static const Color accent = Color(0xFFEE9F27);

  // ---- Surfaces ----
  static const Color background = Color(0xFFF2F6FB); // scaffold tint
  static const Color surface = Color(0xFFFFFFFF); // cards, nav, icon circles

  // ---- Text / neutral ----
  static const Color ink = Color(0xFF12263A);
  static const Color textSecondary = Color(0xFF566A7F);

  /// AA only on [surface] and [background]. Placeholders, captions on white.
  static const Color textTertiary = Color(0xFF5F7286);

  /// Decorative dividers / card edges (NOT a UI-component boundary).
  static const Color border = Color(0xFFD5E1EE);

  /// 3:1 boundary for inputs, unchecked boxes, inactive icons.
  static const Color outline = Color(0xFF7A8FA6);

  /// Disabled fills/labels are exempt from WCAG contrast.
  static const Color disabled = Color(0xFFCBD6E2);
  static const Color onDisabled = Color(0xFF8A9BAD);

  // ---- Semantic ----
  static const Color success = Color(0xFF17794F);
  static const Color successContainer = Color(0xFFE3F4EB);
  static const Color error = Color(0xFFBE2F42);
  static const Color errorContainer = Color(0xFFFDECEE);
  static const Color warning = Color(0xFF8A5300); // text/icon; fills use accent
  static const Color warningContainer = Color(0xFFFDF1DC);
  static const Color info = primary;
  static const Color infoContainer = primaryContainer;

  /// Attendance "half day" and other leave-like statuses (muted violet).
  static const Color statusLeave = Color(0xFF6B4FA0);
  static const Color statusLeaveContainer = Color(0xFFEEE9F8);

  // ---- On-colours ----
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = primaryDark;
  static const Color onPrimaryLight = ink;
  static const Color onSurface = ink;
  static const Color onBackground = ink;
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color onStatusLeave = Color(0xFFFFFFFF);

  /// Dark text/icons on the light `*Container` of each semantic colour.
  /// Chips and badges use container + these, never a solid fill.
  static const Color onSuccessContainer = Color(0xFF0E5C3B);
  static const Color onErrorContainer = Color(0xFF8E1F2F);
  static const Color onWarningContainer = Color(0xFF6B4000);
  static const Color onInfoContainer = primaryDark;
  static const Color onStatusLeaveContainer = Color(0xFF4B3580);

  /// Navy glyph on an accent fill (icons / large text only: 4.43:1).
  static const Color onAccent = primaryDark;

  // ---- Categorical (calendar event types; AA on surface and background) ----
  static const Color categoryOrange = Color(0xFFB04A12);
  static const Color categoryTeal = Color(0xFF0F766E);

  // ---- Misc ----
  static const Color scrim = Color(0xFF0A1B2C);
  static const Color shimmerBase = Color(0xFFE3ECF6);
  static const Color shimmerHighlight = Color(0xFFF4F8FC);
  static const Color shimmerShape = Color(0xFFD5E1EE);

  /// Hero gradient (navy -> primary). White text on both ends is AA.
  static const List<Color> heroGradient = [primaryDark, primary];

  /// Every text/background pair the app is allowed to use, with the minimum
  /// ratio each must meet. Checked by `test/core/design/contrast_test.dart`.
  /// [min] 4.5 = normal text, 3.0 = large text / icons / UI components.
  static const List<EmContrastPair> contrastPairs = [
    EmContrastPair('ink / surface', ink, surface, 4.5),
    EmContrastPair('ink / background', ink, background, 4.5),
    EmContrastPair('ink / primaryContainer', ink, primaryContainer, 4.5),
    EmContrastPair('ink / primaryTint', ink, primaryTint, 4.5),
    EmContrastPair('ink / primaryLight', ink, primaryLight, 4.5),
    EmContrastPair('ink / accent', ink, accent, 4.5),
    EmContrastPair('textSecondary / surface', textSecondary, surface, 4.5),
    EmContrastPair('textSecondary / background', textSecondary, background, 4.5),
    EmContrastPair('textSecondary / primaryContainer', textSecondary, primaryContainer, 4.5),
    EmContrastPair('textSecondary / primaryTint', textSecondary, primaryTint, 4.5),
    EmContrastPair('textTertiary / surface', textTertiary, surface, 4.5),
    EmContrastPair('textTertiary / background', textTertiary, background, 4.5),
    EmContrastPair('primary / surface', primary, surface, 4.5),
    EmContrastPair('primary / background', primary, background, 4.5),
    EmContrastPair('primary / primaryContainer', primary, primaryContainer, 4.5),
    EmContrastPair('primary / primaryTint', primary, primaryTint, 4.5),
    EmContrastPair('primaryDark / surface', primaryDark, surface, 4.5),
    EmContrastPair('primaryDark / background', primaryDark, background, 4.5),
    EmContrastPair('primaryDark / primaryContainer', primaryDark, primaryContainer, 4.5),
    EmContrastPair('primaryDark / primaryLight', primaryDark, primaryLight, 4.5),
    EmContrastPair('onPrimary / primary', onPrimary, primary, 4.5),
    EmContrastPair('onPrimaryDark / primaryDark', onPrimaryDark, primaryDark, 4.5),
    EmContrastPair('primaryLight / primaryDark', primaryLight, primaryDark, 4.5),
    EmContrastPair('onError / error', onError, error, 4.5),
    EmContrastPair('success / surface', success, surface, 4.5),
    EmContrastPair('success / background', success, background, 4.5),
    EmContrastPair('success / successContainer', success, successContainer, 4.5),
    EmContrastPair('error / surface', error, surface, 4.5),
    EmContrastPair('error / background', error, background, 4.5),
    EmContrastPair('error / errorContainer', error, errorContainer, 4.5),
    EmContrastPair('warning / surface', warning, surface, 4.5),
    EmContrastPair('warning / background', warning, background, 4.5),
    EmContrastPair('warning / warningContainer', warning, warningContainer, 4.5),
    EmContrastPair('onSuccess / success', onSuccess, success, 4.5),
    EmContrastPair('onWarning / warning', onWarning, warning, 4.5),
    EmContrastPair('onInfo / info', onInfo, info, 4.5),
    EmContrastPair('onStatusLeave / statusLeave', onStatusLeave, statusLeave, 4.5),
    EmContrastPair('statusLeave / surface', statusLeave, surface, 4.5),
    EmContrastPair('statusLeave / background', statusLeave, background, 4.5),
    EmContrastPair('statusLeave / statusLeaveContainer', statusLeave, statusLeaveContainer, 4.5),
    EmContrastPair('onSuccessContainer / successContainer', onSuccessContainer, successContainer, 4.5),
    EmContrastPair('onErrorContainer / errorContainer', onErrorContainer, errorContainer, 4.5),
    EmContrastPair('onWarningContainer / warningContainer', onWarningContainer, warningContainer, 4.5),
    EmContrastPair('onInfoContainer / infoContainer', onInfoContainer, infoContainer, 4.5),
    EmContrastPair('onStatusLeaveContainer / statusLeaveContainer', onStatusLeaveContainer, statusLeaveContainer, 4.5),
    EmContrastPair('categoryOrange / surface', categoryOrange, surface, 4.5),
    EmContrastPair('categoryOrange / background', categoryOrange, background, 4.5),
    EmContrastPair('categoryTeal / surface', categoryTeal, surface, 4.5),
    EmContrastPair('categoryTeal / background', categoryTeal, background, 4.5),
    // Icons / large text / UI component boundaries (3:1)
    EmContrastPair('onAccent / accent (icon)', onAccent, accent, 3.0),
    EmContrastPair('outline / surface (UI)', outline, surface, 3.0),
    EmContrastPair('outline / background (UI)', outline, background, 3.0),
    EmContrastPair('primary / surface (UI)', primary, surface, 3.0),
    EmContrastPair('primaryMid / surface (icon)', primaryMid, surface, 3.0),
    EmContrastPair('accent / primaryDark (icon)', accent, primaryDark, 3.0),
  ];
}

class EmContrastPair {
  final String name;
  final Color foreground;
  final Color background;
  final double min;
  const EmContrastPair(this.name, this.foreground, this.background, this.min);
}
