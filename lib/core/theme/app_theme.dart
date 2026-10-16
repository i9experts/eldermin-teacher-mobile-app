import 'package:flutter/material.dart';
import '../design/design.dart';

/// LEGACY colour names.
///
/// Every constant is now an alias of a design token in
/// `core/design/tokens/em_colors.dart`, so the whole app re-palettes
/// without touching screens. Aliases are `@Deprecated`; the
/// `deprecated_member_use*` lints are silenced in analysis_options.yaml
/// until the screen restyle batches (D3+) migrate to `EmColors` and this
/// class is deleted. Constants marked UNMAPPED kept their old value because
/// the new monochrome language gives no unambiguous target.
class AppColors {
  AppColors._();

  static const Gradient appbarGradient = LinearGradient(
    colors: [EmColors.primaryDark, Color(0x3D4A89C8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const List<Color> heroGradient = EmColors.heroGradient;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color primaryColor = EmColors.primaryDark;

  @Deprecated('Use EmColors.primaryMid (core/design). Alias kept so screens re-palette without edits.')
  static const Color primaryColorLight = EmColors.primaryMid;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color secondryColor = EmColors.success;

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color secondryColorLight = EmColors.successContainer;

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color accentColor = EmColors.accent;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color lightgradianColor = Color(0x3D4A89C8);

  @Deprecated('Use EmColors.surface (core/design). Alias kept so screens re-palette without edits.')
  static const Color white = EmColors.surface;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color white2 = EmColors.background;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color background = EmColors.background;

  @Deprecated('Use EmColors.ink (core/design). Alias kept so screens re-palette without edits.')
  static const Color textPrimary = EmColors.ink;

  @Deprecated('Use EmColors.ink (core/design). Alias kept so screens re-palette without edits.')
  static const Color black = EmColors.ink;

  @Deprecated('Use EmColors.ink (core/design). Alias kept so screens re-palette without edits.')
  static const Color black2 = EmColors.ink;

  @Deprecated('Use EmColors.ink (core/design). Alias kept so screens re-palette without edits.')
  static const Color blackColor = EmColors.ink;

  static const Color transparent = Colors.transparent;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color grey = EmColors.textSecondary;

  @Deprecated('Use EmColors.textTertiary (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey = EmColors.textTertiary;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey2 = EmColors.border;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey3 = EmColors.background;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey4 = EmColors.background;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey5 = EmColors.outline;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey6 = EmColors.outline;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey7 = EmColors.outline;

  @Deprecated('Use EmColors.textTertiary (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey8 = EmColors.textTertiary;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey9 = EmColors.outline;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey10 = EmColors.background;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey11 = EmColors.border;

  @Deprecated('Use EmColors.disabled (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey12 = EmColors.disabled;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGrey13 = EmColors.border;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color white10 = EmColors.background;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color textPrimaryColor = EmColors.textSecondary;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color textfldFillColor = EmColors.background;

  @Deprecated('Use EmColors.disabled (core/design). Alias kept so screens re-palette without edits.')
  static const Color buttonDisableColor = EmColors.disabled;

  @Deprecated('Use EmColors.warningContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color notificationCircleBg = EmColors.warningContainer;

  @Deprecated('Use EmColors.warningContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color notificationBg = EmColors.warningContainer;

  @Deprecated('Use EmColors.primaryContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color languageBg = EmColors.primaryContainer;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color accepted = EmColors.success;

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color acceptedBg = EmColors.successContainer;

  @Deprecated('Use EmColors.errorContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color failedBg = EmColors.errorContainer;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color delete = EmColors.error;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color green = EmColors.success;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color green2 = EmColors.success;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color red = EmColors.error;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color error = EmColors.error;

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color orange = EmColors.accent;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color fieldsHeadingColor = EmColors.textSecondary;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color textFieldBorderColor = EmColors.outline;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color dividerColor = EmColors.border;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color separatorColor = EmColors.border;

  @Deprecated('Use EmColors.scrim (core/design). Alias kept so screens re-palette without edits.')
  static const Color barrierColor = EmColors.scrim;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color bottomSheetDividerColor = EmColors.border;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color gray600 = EmColors.textSecondary;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color classBg = EmColors.background;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color classBg2 = EmColors.background;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color appBarColor = EmColors.primaryDark;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color greyColor = EmColors.textSecondary;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color dividerColorApp = EmColors.border;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color lightPurple = Color(0xFFF0EDFF);

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGreen = EmColors.successContainer;

  @Deprecated('Use EmColors.warningContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightCameo = EmColors.warningContainer;

  @Deprecated('Use EmColors.errorContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightRed = EmColors.errorContainer;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color seaGreen = EmColors.success;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color americanBlue = EmColors.primaryDark;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color lightPink = Color(0xFFF6E3EC);

  @Deprecated('Use EmColors.primaryContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightBlue = EmColors.primaryContainer;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color redStar = EmColors.error;

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color greenContainerInnerColor = EmColors.successContainer;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color greenContainerBorderColor = EmColors.success;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color darkGreen = EmColors.success;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color bgColorSearchField = EmColors.background;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color purpleColor = Color(0xFF7A63D2);

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightGreyColor = EmColors.border;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color multiSelectColor = EmColors.outline;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color dottedBorderColor = EmColors.outline;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color darkCard = EmColors.primaryDark;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color iosGrey = EmColors.textSecondary;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color greenSuccess = EmColors.success;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color darkDivider = EmColors.primaryDark;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color lightBorder = EmColors.border;

  @Deprecated('Use EmColors.primary (core/design). Alias kept so screens re-palette without edits.')
  static const Color iosBlue = EmColors.primary;

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color iosOrange = EmColors.accent;

  @Deprecated('Use EmColors.textTertiary (core/design). Alias kept so screens re-palette without edits.')
  static const Color inactiveGrey = EmColors.textTertiary;

  @Deprecated('Use EmColors.warningContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color yellowBg = EmColors.warningContainer;

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color yellow = EmColors.accent;

  @Deprecated('Use EmColors.warning (core/design). Alias kept so screens re-palette without edits.')
  static const Color amberDark = EmColors.warning;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color black12 = Color(0x1F000000);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color black38 = Color(0x61000000);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color black54 = Color(0x8A000000);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color black87 = Color(0xDD000000);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color blackOverlay5 = Color(0x0D000000);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color blackOverlay10 = Color(0x1A000000);

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color darkNavBar = EmColors.primaryDark;

  @Deprecated('Use EmColors.shimmerBase (core/design). Alias kept so screens re-palette without edits.')
  static const Color shimmerBase = EmColors.shimmerBase;

  @Deprecated('Use EmColors.shimmerHighlight (core/design). Alias kept so screens re-palette without edits.')
  static const Color shimmerHighlight = EmColors.shimmerHighlight;

  @Deprecated('Use EmColors.shimmerShape (core/design). Alias kept so screens re-palette without edits.')
  static const Color shimmerShape = EmColors.shimmerShape;

  @Deprecated('Use EmColors.shimmerShape (core/design). Alias kept so screens re-palette without edits.')
  static const Color shimmerShapeAlt = EmColors.shimmerShape;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color productPageBg = EmColors.background;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color greyDefault = EmColors.textSecondary;

  @Deprecated('Use EmColors.primaryTint (core/design). Alias kept so screens re-palette without edits.')
  static const Color greySwatch200 = EmColors.primaryTint;

  @Deprecated('Use EmColors.outline (core/design). Alias kept so screens re-palette without edits.')
  static const Color greySwatch400 = EmColors.outline;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color greySwatch600 = EmColors.textSecondary;

  @Deprecated('Use EmColors.primary (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryBlue = EmColors.primary;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color categoryPurple = Color(0xFF7A63D2);

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryTeal = EmColors.success;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryCoral = EmColors.error;

  @Deprecated('Use EmColors.primaryContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryBg1 = EmColors.primaryContainer;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color categoryBg2 = Color(0xFFF0EDFF);

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryBg3 = EmColors.successContainer;

  @Deprecated('Use EmColors.errorContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color categoryBg4 = EmColors.errorContainer;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color facebookBlue = Color(0xFF1877F2);

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color materialAmber = EmColors.accent;

  @Deprecated('Use EmColors.ink (core/design). Alias kept so screens re-palette without edits.')
  static const Color ink = EmColors.ink;

  @Deprecated('Use EmColors.textSecondary (core/design). Alias kept so screens re-palette without edits.')
  static const Color muted = EmColors.textSecondary;

  @Deprecated('Use EmColors.textTertiary (core/design). Alias kept so screens re-palette without edits.')
  static const Color faint = EmColors.textTertiary;

  @Deprecated('Use EmColors.border (core/design). Alias kept so screens re-palette without edits.')
  static const Color line = EmColors.border;

  @Deprecated('Use EmColors.background (core/design). Alias kept so screens re-palette without edits.')
  static const Color canvas = EmColors.background;

  @Deprecated('Use EmColors.primaryDark (core/design). Alias kept so screens re-palette without edits.')
  static const Color navy = EmColors.primaryDark;

  @Deprecated('Use EmColors.primary (core/design). Alias kept so screens re-palette without edits.')
  static const Color blue = EmColors.primary;

  @Deprecated('Use EmColors.primaryMid (core/design). Alias kept so screens re-palette without edits.')
  static const Color sky = EmColors.primaryMid;

  @Deprecated('Use EmColors.primaryContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color pale = EmColors.primaryContainer;

  @Deprecated('Use EmColors.accent (core/design). Alias kept so screens re-palette without edits.')
  static const Color amber = EmColors.accent;

  @Deprecated('Use EmColors.warningContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color amberBg = EmColors.warningContainer;

  @Deprecated('Use EmColors.warning (core/design). Alias kept so screens re-palette without edits.')
  static const Color amberText = EmColors.warning;

  @Deprecated('Use EmColors.successContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color greenBg = EmColors.successContainer;

  @Deprecated('Use EmColors.success (core/design). Alias kept so screens re-palette without edits.')
  static const Color greenText = EmColors.success;

  @Deprecated('Use EmColors.errorContainer (core/design). Alias kept so screens re-palette without edits.')
  static const Color redBg = EmColors.errorContainer;

  @Deprecated('Use EmColors.error (core/design). Alias kept so screens re-palette without edits.')
  static const Color redText = EmColors.error;

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color purple = Color(0xFF7A63D2);

  // UNMAPPED (kept at its old value, see D1A_FOUNDATION.md)
  static const Color purpleBg = Color(0xFFF0EDFF);

  @Deprecated('Use EmColors.surface (core/design). Alias kept so screens re-palette without edits.')
  static const Color surface = EmColors.surface;
}

/// Legacy radius names -> design radii (card 24, hero 28).
class AppRadius {
  AppRadius._();
  static const double sm = EmRadius.sm; // was 10
  static const double md = EmRadius.md; // was 13
  static const double lg = EmRadius.card; // was 19
  static const double xl = EmRadius.hero; // was 23
  static const double pill = EmRadius.pill;
}

/// Legacy spacing names -> 4-based scale.
class AppSpacing {
  AppSpacing._();
  static const double xs = EmSpacing.s4;
  static const double sm = EmSpacing.s8;
  static const double md = EmSpacing.s16; // was 14
  static const double lg = EmSpacing.s20;
  static const double xl = EmSpacing.s32; // was 28
}

/// Semantic color pairs (foreground + tinted background) for badges/tags.
/// Every pair is AA (checked in test/core/design/contrast_test.dart).
class TagStyle {
  final Color fg;
  final Color bg;
  const TagStyle(this.fg, this.bg);

  static const info = TagStyle(EmColors.primary, EmColors.primaryContainer);
  static const amber = TagStyle(EmColors.warning, EmColors.warningContainer);
  static const green = TagStyle(EmColors.success, EmColors.successContainer);
  static const red = TagStyle(EmColors.error, EmColors.errorContainer);
  static const neutral = TagStyle(EmColors.textSecondary, EmColors.primaryTint);
}

class AppTheme {
  AppTheme._();

  /// Entry point used by `main.dart` and every widget test.
  static ThemeData get light => buildEmTheme();
}
