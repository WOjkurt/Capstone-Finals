import 'package:flutter/material.dart';

/// Central color palette meticulously sampled and derived from the
/// Don Bosco Technical College - Cebu (DBTC) official seal:
/// - Gear Blue (#016BC1): Primary color from the gear
/// - Laurel Green (#16A34A / #18D738): Accent from laurel leaves and center hill
/// - Sunburst Amber (#FF9601): Warm accent from the central sunburst rays
/// - Berries Gold (#FACC15): Accent from laurel berries
/// - Midnight Navy (#0A192F): Deep corporate navy undertone for the sidebar
class AppColors {
  // ── Primary Brand Colors (Gear Blue) ───────────────────────────────────────
  static const Color primary = Color(0xFF016BC1);
  static const Color primaryDark = Color(0xFF014F8E);
  static const Color primaryLight = Color(0xFFE8F2FA);
  static const Color primaryHover = Color(0xFF027CDD);

  // ── Secondary Accent (Laurel Green) ────────────────────────────────────────
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentGreenLight = Color(0xFFDCFCE7);
  static const Color accentGreenDark = Color(0xFF15803D);

  // ── Tertiary Accent (Sunburst Amber & Berries Gold) ────────────────────────
  static const Color accentAmber = Color(0xFFFF9601);
  static const Color accentAmberLight = Color(0xFFFEF3C7);
  static const Color accentGold = Color(0xFFFACC15);

  // ── Navigation & Sidebar (Navy Slate) ──────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0A192F);
  static const Color sidebarBorder = Color(0xFF172A45);
  static const Color sidebarActive = Color(0xFF016BC1);
  static const Color sidebarTextMuted = Color(0xFF8892B0);

  // ── Surfaces & Neutrals ───────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  // ── Typography ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Status Colors ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFFF9601);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF016BC1);
}

class AppTheme {
  /// Bundled in assets/fonts. A button `textStyle` replaces the theme's text style instead of
  /// merging with it, so such styles must name this family themselves.
  static const String fontFamily = 'Inter';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        tertiary: AppColors.accentGreen,
        surface: AppColors.cardBg,
      ),
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      // Every message looks the same: floating and rounded. No fixed width: students use phones.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, color: Colors.white),
      ),
      // Cards: white with a light border, as in the Registrar app (no shadow or tint).
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      // One table look: light header row, bold small header text.
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        headingTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
