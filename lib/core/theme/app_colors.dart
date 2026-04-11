import 'dart:ui';

/// EcoCycle Design System — Color Palette
class AppColors {
  AppColors._();

  // ─── Accent ────────────────────────────────────────────
  static const Color neonGreen = Color(0xFF00FFA3);
  static const Color neonGreenDim = Color(0x6600FFA3);

  // ─── Glass Engine Background ───────────────────────────
  static const Color engineBase = Color(0xFF080C0A);
  static const Color blobGreen = Color(0xFF00FFA3);     // ~15 % opacity
  static const Color blobTeal = Color(0xFF00C9A7);      // ~10 % opacity

  // Light Engine
  static const Color lightEngineBase = Color(0xFFF4F9F6);
  static const Color lightBlobMint = Color(0xFF00FFA3);  // ~15 % opacity
  static const Color lightBlobBlue = Color(0xFF00BFFF);  // ~10 % opacity

  // ─── Dark Mode ─────────────────────────────────────────
  static const Color darkBackground = Color(0xFF080C0A);
  static const Color darkSurface = Color(0xFF0F1D17);
  static const Color darkText = Color(0xFFF0F5F2);
  static const Color darkTextSecondary = Color(0x99F0F5F2);

  static const Color darkGlass = Color(0x08FFFFFF);        // white 3 %
  static const Color darkGlassBorder = Color(0x14FFFFFF);  // white 8 %

  // ─── Light Mode ────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F9F6);
  static const Color lightSurface = Color(0xFFF7FBF9);
  static const Color lightText = Color(0xFF0B1410);
  static const Color lightTextSecondary = Color(0x990B1410);

  static const Color lightGlass = Color(0x99FFFFFF);       // white 60 %
  static const Color lightGlassBorder = Color(0x66FFFFFF); // white 40 %
}
