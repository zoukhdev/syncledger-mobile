import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Corporate Modern palette — see DESIGN.md at the repo root.
/// Brand: high-trust fintech. Navy = structure, Emerald = "go/gain", Orange = "action required".
class AppTheme {
  // ── Brand colours ────────────────────────────────────────────
  static const Color navy = Color(0xFF131B2E);            // primary-container
  static const Color navyDeep = Color(0xFF000000);         // primary (text/icons on light)
  static const Color navyMuted = Color(0xFF7C839B);        // on-primary-container
  static const Color emerald = Color(0xFF006C49);          // secondary
  static const Color emeraldLight = Color(0xFF6CF8BB);     // secondary-container
  static const Color emeraldDeep = Color(0xFF00714D);      // on-secondary-container
  static const Color orange = Color(0xFFD95F00);           // tertiary
  static const Color orangeDeep = Color(0xFF783200);       // on-tertiary-container
  static const Color error = Color(0xFFBA1A1A);

  // ── Neutral surface ramp (off-white slate) ───────────────────
  static const Color background = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);
  static const Color outline = Color(0xFFC6C6CD);
  static const Color outlineVariant = Color(0xFFC6C6CD);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF45464D);

  // ── Dark surface ramp ───────────────────────────────────────
  static const Color darkBg = Color(0xFF12141A);
  static const Color darkSurface = Color(0xFF1A1D24);
  static const Color darkSurfaceContainerLow = Color(0xFF1E2129);
  static const Color darkSurfaceContainer = Color(0xFF252932);
  static const Color darkSurfaceContainerHigh = Color(0xFF2D323C);
  static const Color darkOnSurface = Color(0xFFEFF1F3);
  static const Color darkOnSurfaceVariant = Color(0xFFB6BAC2);
  static const Color darkOutline = Color(0xFF45464D);

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      brightness: Brightness.light,
      primary: navyDeep,
      onPrimary: Colors.white,
      primaryContainer: navy,
      onPrimaryContainer: navyMuted,
      secondary: emerald,
      onSecondary: Colors.white,
      secondaryContainer: emeraldLight,
      onSecondaryContainer: emeraldDeep,
      tertiary: orange,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFDBCA),
      onTertiaryContainer: orangeDeep,
      error: error,
      onError: Colors.white,
      surface: background,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.02),
        displayMedium: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.01),
        headlineLarge: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: onSurface),
        bodyMedium: GoogleFonts.inter(color: onSurface),
        labelLarge: GoogleFonts.inter(color: onSurface, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: GoogleFonts.inter(color: onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelSmall: GoogleFonts.inter(color: onSurfaceVariant, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardTheme(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariant),
        hintStyle: const TextStyle(color: onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emeraldDeep,
          side: const BorderSide(color: emerald),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: navyMuted,
      onPrimary: navy,
      primaryContainer: Color(0xFF1F2A45),
      onPrimaryContainer: Color(0xFFBEC6E0),
      secondary: Color(0xFF4EDEA3),
      onSecondary: Color(0xFF002113),
      secondaryContainer: Color(0xFF005236),
      onSecondaryContainer: emeraldLight,
      tertiary: Color(0xFFFFB690),
      onTertiary: Color(0xFF341100),
      tertiaryContainer: Color(0xFF783200),
      onTertiaryContainer: Color(0xFFFFDBCA),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: darkBg,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      surfaceContainerLowest: darkBg,
      surfaceContainerLow: darkSurface,
      surfaceContainer: darkSurfaceContainerLow,
      surfaceContainerHigh: darkSurfaceContainer,
      surfaceContainerHighest: darkSurfaceContainerHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w700, letterSpacing: -0.02),
        displayMedium: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w700, letterSpacing: -0.01),
        headlineLarge: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: darkOnSurface),
        bodyMedium: GoogleFonts.inter(color: darkOnSurface),
        labelLarge: GoogleFonts.inter(color: darkOnSurface, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: GoogleFonts.inter(color: darkOnSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelSmall: GoogleFonts.inter(color: darkOnSurfaceVariant, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyMuted, width: 2),
        ),
        labelStyle: const TextStyle(color: darkOnSurfaceVariant),
        hintStyle: const TextStyle(color: darkOnSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyMuted,
          foregroundColor: navy,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4EDEA3),
          foregroundColor: const Color(0xFF002113),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emeraldLight,
          side: const BorderSide(color: Color(0xFF4EDEA3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
