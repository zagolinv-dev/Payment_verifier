import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// T's Verify — Design System & Theme
/// Color palette: Ethiopian green + gold on dark navy (dark) / sage white (light)
class AppTheme {
  AppTheme._();

  // ── Color Tokens ──────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0A1E12);
  static const Color bgSurface = Color(0xFF0F2819);
  static const Color bgCard = Color(0xFF142F1E);
  static const Color bgCardElevated = Color(0xFF193824);
  static const Color bgInput = Color(0xFF0C2014);

  static const Color primaryGreen = Color(0xFF2DC98E);
  static const Color primaryGreenDim = Color(0xFF1A7A58);
  static const Color primaryGreenDark = Color(0xFF0F4A35);

  static const Color accentGold = Color(0xFFF4A923);
  static const Color accentGoldDim = Color(0xFFF4A92340);

  static const Color success = Color(0xFF2DC98E);
  static const Color error = Color(0xFFFF5C6B);
  static const Color warning = Color(0xFFF4A923);
  static const Color pending = Color(0xFF4E9EFF);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B98B1);
  static const Color textTertiary = Color(0xFF4D5A70);
  static const Color textOnPrimary = Color(0xFF0A1E12);

  static const Color borderSubtle = Color(0xFF1A4028);
  static const Color borderMedium = Color(0xFF205034);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DC98E), Color(0xFF1A7A58)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4A923), Color(0xFFE8851A)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1E12), Color(0xFF0F2819)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C2416), Color(0xFF0F2A1C), Color(0xFF0A1E12)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF193824), Color(0xFF0F2819)],
  );

  // ── Card Decoration ───────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle, width: 1),
      );

  static BoxDecoration get cardGradientDecoration => BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderMedium, width: 1),
      );

  static BoxDecoration glassDecoration({double radius = 20}) => BoxDecoration(
        color: bgCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderMedium, width: 1),
      );

  // ── Light Mode Color Tokens ────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF4F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF0F5F2);
  static const Color lightInput = Color(0xFFF7FAF8);
  static const Color lightBorderSubtle = Color(0xFFE2EBE6);
  static const Color lightBorderMedium = Color(0xFFCBDDD5);
  static const Color lightTextPrimary = Color(0xFF0D1A14);
  static const Color lightTextSecondary = Color(0xFF4D6B5C);
  static const Color lightTextTertiary = Color(0xFF8AADA0);

  // ── Light Gradients ───────────────────────────────────────────────────────
  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEDF7F2), Color(0xFFF4F7F5)],
  );

  // ── System UI Overlay Styles ──────────────────────────────────────────────
  static SystemUiOverlayStyle get darkOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: bgDark,
        systemNavigationBarIconBrightness: Brightness.light,
      );

  static SystemUiOverlayStyle get lightOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: lightBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  // ── Theme Data (DARK) ─────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: accentGold,
        surface: bgSurface,
        error: error,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      textTheme: _buildTextTheme(base.textTheme, textPrimary, textSecondary, textTertiary),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSurface,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textTertiary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: textOnPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(bgInput, borderSubtle, textTertiary, textSecondary),
      chipTheme: ChipThemeData(
        backgroundColor: bgCard,
        selectedColor: primaryGreenDark,
        side: const BorderSide(color: borderSubtle),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCardElevated,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Theme Data (LIGHT) ────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentGold,
        surface: lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(base.textTheme, lightTextPrimary, lightTextSecondary, lightTextTertiary),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: lightTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryGreen,
        unselectedItemColor: lightTextTertiary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(lightInput, lightBorderSubtle, lightTextTertiary, lightTextSecondary),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard,
        selectedColor: primaryGreen.withOpacity(0.12),
        side: BorderSide(color: lightBorderSubtle),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: lightTextSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: lightBorderSubtle, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCard,
        contentTextStyle: GoogleFonts.inter(color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: lightBorderSubtle),
        ),
      ),
    );
  }

  // ── Shared Text Theme Builder ──────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary, Color tertiary) {
    return GoogleFonts.outfitTextTheme(base).copyWith(
      displayLarge: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.3),
      headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: primary),
      headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: tertiary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
    );
  }

  // ── Shared Input Theme Builder ─────────────────────────────────────────────
  static InputDecorationTheme _buildInputTheme(
    Color fill, Color border, Color hint, Color label) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(color: hint, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: label, fontSize: 14),
    );
  }
}
