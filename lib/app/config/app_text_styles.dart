import '../../core/design/tokens/em_typography.dart';

/// Font family names for the components under `app/components/`, as plain
/// compile-time constants. Both point at the bundled Plus Jakarta Sans
/// (`EmType.family`, declared in pubspec.yaml); nothing is fetched at runtime.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = EmType.family;
  static const String headingFontFamily = EmType.family;
}
