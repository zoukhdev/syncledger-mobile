import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Zinc Light Palette
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc300 = Color(0xFFD4D4D8);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc950 = Color(0xFF09090B);

  // Accents
  static const Color interactiveLight = Color(0xFF18181B);
  static const Color interactiveDark = Color(0xFFFAFAFA);
  static const Color danger = Color(0xFFEF4444); // red-500
  static const Color success = Color(0xFF10B981); // emerald-500

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: zinc50,
      colorScheme: const ColorScheme.light(
        primary: interactiveLight,
        secondary: zinc800,
        surface: zinc100,
        onSurface: zinc900,
        error: danger,
        outline: zinc200,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(color: zinc900, fontWeight: FontWeight.w300),
        displayMedium: GoogleFonts.inter(color: zinc900, fontWeight: FontWeight.w300),
        titleLarge: GoogleFonts.inter(color: zinc900, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: zinc900),
        bodyMedium: GoogleFonts.inter(color: zinc900),
      ),
      cardTheme: CardTheme(
        color: zinc100,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zinc200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zinc100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: zinc300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: zinc300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: interactiveLight, width: 2),
        ),
        labelStyle: const TextStyle(color: zinc800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: interactiveLight,
          foregroundColor: zinc50,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: zinc950,
      colorScheme: const ColorScheme.dark(
        primary: interactiveDark,
        secondary: zinc300,
        surface: zinc900,
        onSurface: zinc50,
        error: danger,
        outline: zinc800,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(color: zinc50, fontWeight: FontWeight.w300),
        displayMedium: GoogleFonts.inter(color: zinc50, fontWeight: FontWeight.w300),
        titleLarge: GoogleFonts.inter(color: zinc50, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: zinc50),
        bodyMedium: GoogleFonts.inter(color: zinc50),
      ),
      cardTheme: CardTheme(
        color: zinc900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zinc800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zinc900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: zinc800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: zinc800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: interactiveDark, width: 2),
        ),
        labelStyle: const TextStyle(color: zinc300),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: interactiveDark,
          foregroundColor: zinc950,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
