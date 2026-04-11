import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Both themes set splashColor / highlightColor to transparent
/// so no default Material ripple effects leak through our custom hover system.
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.5),
      displayMedium: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.5),
      displaySmall: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: primary),
      headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: primary),
      titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.5),
    );
  }

  // ── Dark ────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.darkSurface,
          primary: AppColors.neonGreen,
          secondary: AppColors.neonGreen,
          onPrimary: AppColors.darkBackground,
          onSurface: AppColors.darkText,
          onSecondary: AppColors.darkBackground,
        ),
        textTheme: _textTheme(AppColors.darkText, AppColors.darkTextSecondary),
        iconTheme: const IconThemeData(color: AppColors.darkTextSecondary, size: 22),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        dividerColor: Colors.transparent,
      );

  // ── Light ───────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.light(
          surface: AppColors.lightSurface,
          primary: AppColors.neonGreen,
          secondary: AppColors.neonGreen,
          onPrimary: Colors.white,
          onSurface: AppColors.lightText,
          onSecondary: Colors.white,
        ),
        textTheme: _textTheme(AppColors.lightText, AppColors.lightTextSecondary),
        iconTheme: const IconThemeData(color: AppColors.lightTextSecondary, size: 22),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        dividerColor: Colors.transparent,
      );
}
