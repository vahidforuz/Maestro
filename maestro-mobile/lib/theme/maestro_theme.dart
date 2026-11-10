import 'package:flutter/material.dart';

class MaestroColors {
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const sidebar = Color(0xFF111827);
  static const sidebarHover = Color(0xFF1F2937);
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF1D4ED8);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const subtleBlue = Color(0xFFEAF1FF);
  static const successBg = Color(0xFFDCFCE7);
  static const successText = Color(0xFF166534);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningText = Color(0xFF92400E);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerText = Color(0xFF991B1B);
  static const neutralBg = Color(0xFFF3F4F6);
}

class MaestroTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MaestroColors.primary,
        primary: MaestroColors.primary,
        surface: MaestroColors.surface,
        error: MaestroColors.error,
      ),
      scaffoldBackgroundColor: MaestroColors.background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: MaestroColors.text,
        displayColor: MaestroColors.text,
        fontFamilyFallback: const ['Segoe UI', 'Helvetica Neue', 'Arial'],
      ),
      cardTheme: CardThemeData(
        color: MaestroColors.surface,
        elevation: 1,
        shadowColor: MaestroColors.text.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MaestroColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MaestroColors.surface,
        foregroundColor: MaestroColors.text,
        elevation: 0,
        surfaceTintColor: MaestroColors.surface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MaestroColors.surface,
        indicatorColor: MaestroColors.subtleBlue,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: MaestroColors.surface,
        indicatorColor: MaestroColors.subtleBlue,
        minWidth: 84,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MaestroColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MaestroColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MaestroColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
