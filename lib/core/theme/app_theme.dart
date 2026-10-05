import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Exact palette from the approved mockup (eldermin_parent_app_v2.html),
/// not an approximation - every hex here matches a CSS var in that file.
class AppColors {
  AppColors._();
  static const Gradient appbarGradient = LinearGradient(
    colors: [AppColors.primaryColor, AppColors.lightgradianColor],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const Color primaryColor = Color(0xFF0A3158); // navy
  static const Color primaryColorLight = Color(0xFF4C98D2); // sky
  static const Color secondryColor = Color(0xFF25A878); // green
  static const Color secondryColorLight = Color(0xFF6FD3AE);
  static const Color accentColor = Color(0xFFF5A623); // amber
  static const Color lightgradianColor = Color.fromARGB(60, 76, 152, 210);

  static const Color white = Color(0xFFFFFFFF);
  static const Color white2 = Color(0xFFEEF4F8);
  static const Color background = Color(0xFFF5F8FB);
  static const Color textPrimary = Color.fromARGB(230, 16, 37, 58);
  static const Color black = Color(0xFF10253A); // ink
  static const Color black2 = Color(0xFF0D1F30);
  static const Color blackColor = Color(0xFF0A3158); // navy
  static const Color transparent = Colors.transparent;
  static const Color grey = Color(0xFF6C7D8E); // muted
  static const Color lightGrey = Color(0xFF94A3B2); // faint
  static const Color lightGrey2 = Color(0xFFE6EDF3); // line
  static const Color lightGrey3 = Color(0xFFF5F8FB);
  static const Color lightGrey4 = Color(0xFFEDF2F6);
  static const Color lightGrey5 = Color(0xFFB9C6D0);
  static const Color lightGrey6 = Color(0xFFA7B6C2);
  static const Color lightGrey7 = Color(0xFF9AA9B6);
  static const Color lightGrey8 = Color(0xFF94A3B2);
  static const Color lightGrey9 = Color(0xFF8496A4);
  static const Color lightGrey10 = Color(0xFFEEF4F8);
  static const Color lightGrey11 = Color(0xFFE2E9EF);
  static const Color lightGrey12 = Color(0xFFC3CED7);
  static const Color lightGrey13 = Color(0xFFD7E0E7);

  static const Color white10 = Color(0xFFF2F6F9);
  static const Color textPrimaryColor = Color(0xFF6C7D8E);

  static const Color textfldFillColor = Color(0xFFEEF4F8);
  static const Color buttonDisableColor = Color(0xFFC7D2DA);
  static const Color notificationCircleBg = Color(0xFFFFF3DC);
  static const Color notificationBg = Color(0xFFFFE9C2);
  static const Color languageBg = Color(0xFFE9F4FC);

  static const Color accepted = Color(0xFF25A878);
  static const Color acceptedBg = Color(0xFFE7F8F1);

  static const Color failedBg = Color(0xFFFEECEF);

  static const Color delete = Color(0xFFE35A65);
  static const Color green = Color(0xFF25A878);
  static const Color green2 = Color(0xFF1F9269);
  static const Color red = Color(0xFFE35A65);
  static const Color error = Color(0xFFC83E4D);

  static const Color orange = Color(0xFFF5A623); // amber

  static const Color fieldsHeadingColor = Color(0xFF6C7D8E);
  static const Color textFieldBorderColor = Color(0xFFE6EDF3);
  static const Color dividerColor = Color(0xFFE6EDF3);
  static const Color separatorColor = Color(0xFFDCE7EF);
  static const Color barrierColor = Color(0xFF0A1B2C);
  static const Color bottomSheetDividerColor = Color(0xFFEEF4F8);
  static const Color gray600 = Color(0xFF6C7D8E);

  static const Color classBg = Color(0xFFEEF4F8);
  static const Color classBg2 = Color(0xFFF5F8FB);

  static const Color appBarColor = Color(0xFF0A3158); // navy
  static const Color greyColor = Color(0xFF6C7D8E);
  static const Color dividerColorApp = Color(0xFFE6EDF3);
  static const Color lightPurple = Color(0xFFF0EDFF);
  static const Color lightGreen = Color(0xFFE7F8F1);
  static const Color lightCameo = Color(0xFFFFF3DC);
  static const Color lightRed = Color(0xFFFEECEF);
  static const Color seaGreen = Color(0xFF25A878);
  static const Color americanBlue = Color(0xFF0A3158);
  static const Color lightPink = Color(0xFFF6E3EC);
  static const Color lightBlue = Color(0xFFE9F4FC);
  static const Color redStar = Color(0xFFE35A65);

  static const Color greenContainerInnerColor = Color(0xFFE7F8F1);
  static const Color greenContainerBorderColor = Color(0xFF25A878);
  static const Color darkGreen = Color(0xFF18835C);

  static const Color bgColorSearchField = Color(0xFFEEF4F8);
  static const Color purpleColor = Color(0xFF7A63D2);

  static const Color lightGreyColor = Color(0xFFDCE7EF);

  static const Color multiSelectColor = Color(0xFF94A3B2);

  static const Color dottedBorderColor = Color(0xFF6C7D8E);

  // Dark-theme placeholders (kept for compatibility; app is light-only today)
  static const Color darkCard = Color(0xFF13314F);
  static const Color iosGrey = Color(0xFF6C7D8E);
  static const Color greenSuccess = Color(0xFF25A878);
  static const Color darkDivider = Color(0xFF1B4062);
  static const Color lightBorder = Color(0xFFE6EDF3);
  static const Color iosBlue = Color(0xFF1768AA);
  static const Color iosOrange = Color(0xFFF5A623);
  static const Color inactiveGrey = Color(0xFF94A3B2);

  static const Color yellowBg = Color(0xFFFFF3DC);
  static const Color yellow = Color(0xFFF5A623);
  static const Color amberDark = Color(0xFFB86C00);

  static const Color black12 = Color(0x1F000000);
  static const Color black38 = Color(0x61000000);
  static const Color black54 = Color(0x8A000000);
  static const Color black87 = Color(0xDD000000);
  static const Color blackOverlay5 = Color(0x0D000000);
  static const Color blackOverlay10 = Color(0x1A000000);

  static const Color darkNavBar = Color(0xFF0A3158);

  static const Color shimmerBase = Color(0xFFE3EAF0);
  static const Color shimmerHighlight = Color(0xFFF3F7FA);
  static const Color shimmerShape = Color(0xFFD7E1E8);
  static const Color shimmerShapeAlt = Color(0xFFD9E2E9);
  static const Color productPageBg = Color(0xFFEEF4F8);

  static const Color greyDefault = Color(0xFF6C7D8E);
  static const Color greySwatch200 = Color(0xFFEDF2F6);
  static const Color greySwatch400 = Color(0xFFB9C6D0);
  static const Color greySwatch600 = Color(0xFF6C7D8E);

  static const Color categoryBlue = Color(0xFF1768AA);
  static const Color categoryPurple = Color(0xFF7A63D2);
  static const Color categoryTeal = Color(0xFF25A878);
  static const Color categoryCoral = Color(0xFFE35A65);

  static const Color categoryBg1 = Color(0xFFE9F4FC);
  static const Color categoryBg2 = Color(0xFFF0EDFF);
  static const Color categoryBg3 = Color(0xFFE7F8F1);
  static const Color categoryBg4 = Color(0xFFFEECEF);

  static const Color facebookBlue = Color(0xFF1877F2);

  static const Color materialAmber = Color(0xFFF5A623);
  static const Color ink = Color(0xFF10253A);
  static const Color muted = Color(0xFF6C7D8E);
  static const Color faint = Color(0xFF94A3B2);
  static const Color line = Color(0xFFE6EDF3);
  static const Color canvas = Color(0xFFEEF4F8);

  static const Color navy = Color(0xFF0A3158);
  static const Color blue = Color(0xFF1768AA);
  static const Color sky = Color(0xFF4C98D2);
  static const Color pale = Color(0xFFE9F4FC);
  static const Color amber = Color(0xFFF5A623);
  static const Color amberBg = Color(0xFFFFF3DC);
  static const Color amberText = Color(0xFFB86C00);

  static const Color greenBg = Color(0xFFE7F8F1);
  static const Color greenText = Color(0xFF18835C);
  // static const Color red = Color(0xFFE35A65);
  static const Color redBg = Color(0xFFFEECEF);
  static const Color redText = Color(0xFFC83E4D);
  static const Color purple = Color(0xFF7A63D2);
  static const Color purpleBg = Color(0xFFF0EDFF);

  static const List<Color> heroGradient = [
    navy,
    Color(0xFF155D96),
    Color(0xFF237FBD)
  ];

  static const Color surface = Colors.white;
  // static const Color background = Color(0xFFF5F8FB);
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 13;
  static const double lg = 19;
  static const double xl = 23;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Semantic color pairs (foreground + tinted background) for badges/tags,
/// matching the mockup's .tag / .tag.amber / .tag.green / .tag.red classes.
class TagStyle {
  final Color fg;
  final Color bg;
  const TagStyle(this.fg, this.bg);

  static const info = TagStyle(AppColors.blue, AppColors.pale);
  static const amber = TagStyle(AppColors.amberText, AppColors.amberBg);
  static const green = TagStyle(AppColors.greenText, AppColors.greenBg);
  static const red = TagStyle(AppColors.redText, AppColors.redBg);
  static const neutral = TagStyle(AppColors.muted, AppColors.line);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: AppColors.primaryColor,
          letterSpacing: -1),
      headlineMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: AppColors.primaryColor,
          fontSize: 23,
          letterSpacing: -0.75),
      headlineSmall: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 18),
      titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14),
      titleMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13),
      bodyLarge: GoogleFonts.inter(color: AppColors.ink, fontSize: 15),
      bodyMedium: GoogleFonts.inter(color: AppColors.muted, fontSize: 12.5),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryColor,
        secondary: AppColors.amber,
        error: AppColors.red,
        surface: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.blue)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.red)),
        hintStyle: const TextStyle(color: AppColors.faint),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.faint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
