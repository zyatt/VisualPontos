import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color orange = Color(0xFFF2711C);
  static const Color error = Color(0xFFE05252);

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: orange,
      onPrimary: Colors.white,
      secondary: orange,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      onSurface: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A),
      surfaceContainerHighest: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      onSurfaceVariant: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7A),
      outline: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF4F4F4),
      colorScheme: scheme,
      textTheme: GoogleFonts.nunitoTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      useMaterial3: true,
    );
  }
}
