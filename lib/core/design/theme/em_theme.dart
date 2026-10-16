import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_shadows.dart';
import '../tokens/em_typography.dart';

/// Builds the app [ThemeData] purely from design tokens. `AppTheme.light`
/// (core/theme/app_theme.dart) delegates here.
ThemeData buildEmTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: EmColors.primary,
    onPrimary: EmColors.onPrimary,
    primaryContainer: EmColors.primaryContainer,
    onPrimaryContainer: EmColors.onPrimaryContainer,
    secondary: EmColors.accent,
    onSecondary: EmColors.onAccent,
    secondaryContainer: EmColors.primaryLight,
    onSecondaryContainer: EmColors.onPrimaryLight,
    tertiary: EmColors.primaryMid,
    onTertiary: EmColors.ink,
    error: EmColors.error,
    onError: EmColors.onError,
    errorContainer: EmColors.errorContainer,
    onErrorContainer: EmColors.error,
    surface: EmColors.surface,
    onSurface: EmColors.onSurface,
    onSurfaceVariant: EmColors.textSecondary,
    surfaceContainerLowest: EmColors.surface,
    surfaceContainerLow: EmColors.surface,
    surfaceContainer: EmColors.background,
    surfaceContainerHigh: EmColors.primaryTint,
    surfaceContainerHighest: EmColors.primaryContainer,
    outline: EmColors.outline,
    outlineVariant: EmColors.border,
    shadow: EmColors.primaryDark,
    scrim: EmColors.scrim,
    surfaceTint: Colors.transparent,
  );

  TextStyle c(TextStyle s, Color color) => s.copyWith(color: color);
  final textTheme = TextTheme(
    displayLarge: c(EmType.display, EmColors.ink),
    displayMedium: c(EmType.display, EmColors.ink),
    displaySmall: c(EmType.title, EmColors.ink),
    headlineLarge: c(EmType.title, EmColors.ink),
    headlineMedium: c(EmType.title, EmColors.ink),
    headlineSmall: c(EmType.heading, EmColors.ink),
    titleLarge: c(EmType.heading, EmColors.ink),
    titleMedium: c(EmType.bodyLarge, EmColors.ink),
    titleSmall: c(EmType.label, EmColors.ink),
    bodyLarge: c(EmType.bodyLarge, EmColors.ink),
    bodyMedium: c(EmType.body, EmColors.ink),
    bodySmall: c(EmType.caption, EmColors.textSecondary),
    labelLarge: c(EmType.label, EmColors.ink),
    labelMedium: c(EmType.caption, EmColors.textSecondary),
    labelSmall: c(EmType.navLabel, EmColors.textSecondary),
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: EmRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );

  const buttonShape = StadiumBorder();
  const buttonSize = Size(64, 52);
  const buttonPadding = EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: EmType.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: EmColors.background,
    canvasColor: EmColors.background,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: const IconThemeData(color: EmColors.ink, size: 24),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: EmColors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: EmColors.background,
      foregroundColor: EmColors.ink,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
      titleTextStyle: c(EmType.heading, EmColors.ink),
      iconTheme: const IconThemeData(color: EmColors.ink),
      actionsIconTheme: const IconThemeData(color: EmColors.ink),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: const CardThemeData(
      color: EmColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: EmRadius.cardAll),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EmColors.primary,
        foregroundColor: EmColors.onPrimary,
        disabledBackgroundColor: EmColors.disabled,
        disabledForegroundColor: EmColors.onDisabled,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EmColors.primary,
        foregroundColor: EmColors.onPrimary,
        disabledBackgroundColor: EmColors.disabled,
        disabledForegroundColor: EmColors.onDisabled,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EmColors.primary,
        disabledForegroundColor: EmColors.onDisabled,
        side: const BorderSide(color: EmColors.primaryLight, width: 1.5),
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EmColors.primary,
        disabledForegroundColor: EmColors.onDisabled,
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: EmColors.ink,
        minimumSize: const Size(48, 48),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: EmColors.accent,
      foregroundColor: EmColors.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EmColors.surface,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(EmColors.outline),
      enabledBorder: inputBorder(EmColors.outline),
      focusedBorder: inputBorder(EmColors.primary, 2),
      errorBorder: inputBorder(EmColors.error, 1.5),
      focusedErrorBorder: inputBorder(EmColors.error, 2),
      disabledBorder: inputBorder(EmColors.border),
      hintStyle: c(EmType.body, EmColors.textTertiary),
      labelStyle: c(EmType.body, EmColors.textSecondary),
      floatingLabelStyle: c(EmType.label, EmColors.primary),
      helperStyle: c(EmType.caption, EmColors.textSecondary),
      errorStyle: c(EmType.caption, EmColors.error),
      prefixIconColor: EmColors.textSecondary,
      suffixIconColor: EmColors.textSecondary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: EmColors.surface,
      selectedColor: EmColors.primaryLight,
      disabledColor: EmColors.disabled,
      side: const BorderSide(color: EmColors.border),
      shape: const StadiumBorder(),
      labelStyle: c(EmType.label, EmColors.ink),
      secondaryLabelStyle: c(EmType.label, EmColors.ink),
      checkmarkColor: EmColors.primaryDark,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: EmColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: EmRadius.cardAll),
      titleTextStyle: c(EmType.heading, EmColors.ink),
      contentTextStyle: c(EmType.body, EmColors.textSecondary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: EmColors.surface,
      modalBackgroundColor: EmColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x660A1B2C),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EmRadius.hero)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EmColors.ink,
      contentTextStyle: c(EmType.body, EmColors.surface),
      actionTextColor: EmColors.primaryLight,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: EmRadius.mdAll),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: EmColors.ink,
      unselectedLabelColor: EmColors.textSecondary,
      labelStyle: EmType.label,
      unselectedLabelStyle: EmType.label,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: const BoxDecoration(color: EmColors.primaryLight, borderRadius: EmRadius.pillAll),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: EmColors.border, thickness: 1, space: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: EmColors.surface,
      selectedItemColor: EmColors.primary,
      unselectedItemColor: EmColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: EmType.navLabel,
      unselectedLabelStyle: EmType.navLabel,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: EmColors.primary,
      linearTrackColor: EmColors.primaryContainer,
      circularTrackColor: EmColors.primaryContainer,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EmColors.onPrimary : EmColors.outline),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EmColors.primary : EmColors.primaryContainer),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : EmColors.outline),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EmColors.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(EmColors.onPrimary),
      side: const BorderSide(color: EmColors.outline, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EmColors.primary : EmColors.outline),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: EmColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: EmRadius.mdAll),
      textStyle: c(EmType.body, EmColors.ink),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: EmColors.primary,
      selectionColor: EmColors.primaryLight,
      selectionHandleColor: EmColors.primary,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: EmColors.primary,
      textColor: EmColors.ink,
      titleTextStyle: c(EmType.body, EmColors.ink),
      subtitleTextStyle: c(EmType.caption, EmColors.textSecondary),
    ),
    // Soft shadow token is exposed for widgets; theme itself is flat.
    extensions: const <ThemeExtension<dynamic>>[EmShadowsExtension()],
  );
}

/// Placeholder so `Theme.of(context).extension<EmShadowsExtension>()` can
/// expose [EmShadows] to widgets that prefer theme lookup over imports.
@immutable
class EmShadowsExtension extends ThemeExtension<EmShadowsExtension> {
  const EmShadowsExtension();
  List<BoxShadow> get soft => EmShadows.soft;
  List<BoxShadow> get nav => EmShadows.nav;
  List<BoxShadow> get fab => EmShadows.fab;
  @override
  EmShadowsExtension copyWith() => this;
  @override
  EmShadowsExtension lerp(ThemeExtension<EmShadowsExtension>? other, double t) => this;
}
