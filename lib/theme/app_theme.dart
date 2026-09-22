import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const canvas = Color(0xFFF4F7FB);
  static const card = Color(0xFFFFFFFF);
  static const navy = Color(0xFF1E3A5F);
  static const fabRed = Color(0xFFE53935);
  static const accent = Color(0xFF1976D2);
  static const sky = Color(0xFF0B4F8A);
  static const kite = Color(0xFFE85D04);
  static const mist = canvas;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: accent,
      secondary: fabRed,
      surface: card,
      error: fabRed,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF0F172A), fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Color(0xFF0F172A), fontSize: 14, height: 1.35),
        titleMedium: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fabRed,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: const Color(0x140F172A),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: fabRed,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        elevation: 8,
        shadowColor: const Color(0x140F172A),
        indicatorColor: const Color(0xFFE3F2FD),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accent : const Color(0xFF64748B));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? accent : const Color(0xFF64748B),
          );
        }),
      ),
    );
  }

  static ThemeData dark() {
    const canvasDark = Color(0xFF0F172A);
    const cardDark = Color(0xFF1E293B);
    const scheme = ColorScheme.dark(
      primary: Color(0xFF93C5FD),
      secondary: fabRed,
      surface: cardDark,
      error: fabRed,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvasDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: fabRed,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardDark,
        indicatorColor: const Color(0xFF7F1D1D),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
