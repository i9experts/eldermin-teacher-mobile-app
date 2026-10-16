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
}
