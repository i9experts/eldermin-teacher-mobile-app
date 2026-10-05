/// Matches the family already loaded app-wide by
/// `GoogleFonts.interTextTheme` in `core/theme/app_theme.dart` — a plain
/// literal here (not a `GoogleFonts.inter()` call) so it stays usable as a
/// compile-time constant default value in the components under
/// `app/components/`.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter';
  static const String headingFontFamily = 'Inter';
}
