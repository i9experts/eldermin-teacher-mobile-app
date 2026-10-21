import 'package:flutter/painting.dart';
import 'em_colors.dart';

/// Elevation is expressed through tint first; shadows are faint and wide.
class EmShadows {
  EmShadows._();

  static const List<BoxShadow> none = [];

  /// White card / icon circle on the tinted scaffold.
  static final List<BoxShadow> soft = [
    BoxShadow(color: EmColors.primaryDark.withAlpha(13), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  /// Bottom navigation bar (casts upwards).
  static final List<BoxShadow> nav = [
    BoxShadow(color: EmColors.primaryDark.withAlpha(18), blurRadius: 20, offset: const Offset(0, -4)),
  ];

  /// The only clearly elevated element: the diamond FAB.
  static final List<BoxShadow> fab = [
    BoxShadow(color: EmColors.primaryDark.withAlpha(71), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}
