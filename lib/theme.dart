import 'package:flutter/material.dart';

class Brand {
  static const navy = Color(0xFF0B3D6E);
  static const navyDark = Color(0xFF061B33);
  static const ice = Color(0xFF14B8E6);
  static const iceDeep = Color(0xFF0284C7);
  static const mint = Color(0xFF10B981);
  static const surface = Color(0xFFF4F8FB);
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF5B6B80);
  static const line = Color(0xFFE2E9F0);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navyDark],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.navy,
    primary: Brand.navy,
    secondary: Brand.iceDeep,
    tertiary: Brand.mint,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Inter');
  final text = base.textTheme.apply(bodyColor: Brand.ink, displayColor: Brand.ink);
  TextStyle? head(TextStyle? s) => s?.copyWith(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, letterSpacing: -0.3);

  return base.copyWith(
    scaffoldBackgroundColor: Brand.surface,
    textTheme: text.copyWith(
      displaySmall: head(text.displaySmall),
      headlineLarge: head(text.headlineLarge),
      headlineMedium: head(text.headlineMedium),
      headlineSmall: head(text.headlineSmall),
      titleLarge: head(text.titleLarge),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.surface,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 20, color: Brand.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Brand.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Inter'),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.navy,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Brand.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter'),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Brand.iceDeep, width: 2)),
    ),
    sliderTheme: const SliderThemeData(trackHeight: 8),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
