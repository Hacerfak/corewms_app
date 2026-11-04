import 'package:flutter/material.dart';

class AppTheme {
  // Cores de Ação (Vibrantes em ambos os temas)
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDanger = Color(0xFFEF4444);

  // ==========================================
  // TEMA ESCURO (DARK THEME - SLATE 900)
  // ==========================================
  static ThemeData get darkTheme {
    const bgDark = Color(0xFF0F172A); // Slate 900
    const surfaceDark = Color(0xFF1E293B); // Slate 800
    const borderDark = Color(0xFF334155); // Slate 700

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      cardColor: surfaceDark,
      canvasColor: surfaceDark,
      dividerColor: borderDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        surface: surfaceDark,
        surfaceContainerHighest: bgDark,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFF94A3B8),
        outline: borderDark,
        error: roseDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgDark,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ==========================================
  // TEMA CLARO (LIGHT THEME - SLATE 100/WHITE)
  // ==========================================
  static ThemeData get lightTheme {
    const bgLight = Color(0xFFF1F5F9); // Slate 100
    const surfaceLight = Colors.white;
    const borderLight = Color(0xFFCBD5E1); // Slate 300

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      cardColor: surfaceLight,
      canvasColor: surfaceLight,
      dividerColor: borderLight,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        surface: surfaceLight,
        surfaceContainerHighest: Color(0xFFF8FAFC),
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF64748B),
        outline: borderLight,
        error: roseDanger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Extensão semântica para qualquer Widget acessar as cores dinâmicas:
/// context.bg, context.card, context.cardSubtle, context.border, context.textPrimary, context.textSecondary
extension AppThemeContextExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get card => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardSubtle =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get border =>
      isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
}
