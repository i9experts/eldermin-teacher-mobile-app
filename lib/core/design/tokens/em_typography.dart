import 'package:flutter/painting.dart';

/// Plus Jakarta Sans (bundled, SIL OFL 1.1). Weights 400/500/600/700 only;
/// the default weights of the scale are 500-600 (REFERENCE_SPEC section 2).
///
/// Styles carry NO colour: callers (or the theme) supply it.
class EmType {
  EmType._();
  static const String family = 'PlusJakartaSans';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(fontFamily: family, fontSize: 28, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.4);
  static const TextStyle title = TextStyle(fontFamily: family, fontSize: 22, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const TextStyle heading = TextStyle(fontFamily: family, fontSize: 18, height: 1.3, fontWeight: FontWeight.w600);
  static const TextStyle bodyLarge = TextStyle(fontFamily: family, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500);
  static const TextStyle body = TextStyle(fontFamily: family, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500);
  static const TextStyle bodyRegular = TextStyle(fontFamily: family, fontSize: 14, height: 1.4, fontWeight: FontWeight.w400);
  static const TextStyle label = TextStyle(fontFamily: family, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600);
  static const TextStyle caption = TextStyle(fontFamily: family, fontSize: 12, height: 1.3, fontWeight: FontWeight.w500);

  /// Values in charts / timers / stat tiles: bold, tabular figures.
  static const TextStyle value = TextStyle(fontFamily: family, fontSize: 20, height: 1.2, fontWeight: FontWeight.w600, fontFeatures: _tabular);
  static const TextStyle valueSmall = TextStyle(fontFamily: family, fontSize: 15, height: 1.2, fontWeight: FontWeight.w600, fontFeatures: _tabular);
  static const TextStyle navLabel = TextStyle(fontFamily: family, fontSize: 11, height: 1.2, fontWeight: FontWeight.w500);
}
