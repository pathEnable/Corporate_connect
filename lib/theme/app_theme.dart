import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Emini Identity Colors
  static const Color primaryTurquoise = Color(0xFF26E9CF);
  static const Color deepBlack = Color(0xFF121212); // Anthracite au lieu de Noir pur
  static const Color surfaceDark = Color(0xFF1E1E1E); // Gris plus doux
  static const Color surfaceLight = Color(0xFFF8F9FA);

  static ThemeData lightTheme(double fontScale, {int? accentColorValue}) {
    final primaryColor = accentColorValue != null ? Color(accentColorValue) : primaryTurquoise;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        onPrimary: Colors.black,
        surface: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F9FB),
        surfaceContainer: const Color(0xFFF0F3F6),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surfaceLight,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withAlpha(20))),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: Colors.black.withAlpha(220),
        displayColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
          elevation: 2,
          shadowColor: primaryColor.withAlpha(100),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F3F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static ThemeData darkTheme(double fontScale, {int? accentColorValue}) {
    final primaryColor = accentColorValue != null ? Color(accentColorValue) : primaryTurquoise;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        onPrimary: Colors.black,
        surface: deepBlack,
        surfaceContainerLowest: deepBlack,
        surfaceContainerLow: const Color(0xFF1A1A1A),
        surfaceContainer: const Color(0xFF222222),
        brightness: Brightness.dark,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: deepBlack, // Utilisation de l'Anthracite défini plus haut
      cardTheme: CardThemeData(
        color: const Color(0xFF141414),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withAlpha(10))),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white.withAlpha(230),
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
          elevation: 4,
          shadowColor: primaryColor.withAlpha(120),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
