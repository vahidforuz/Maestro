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

class MaestroAccents {
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFEC4899);
  static const cyan = Color(0xFF06B6D4);

  static Color tint(Color accent, Color surface, Brightness brightness) =>
      Color.alphaBlend(
        accent.withValues(alpha: brightness == Brightness.dark ? .20 : .11),
        surface,
      );

  // Darker foreground colors keep icons readable on the light tints.
  static Color foreground(Color accent, Brightness brightness) {
    if (brightness == Brightness.dark) return accent;
    if (accent == green) return const Color(0xFF047857);
    if (accent == orange) return const Color(0xFF9A5700);
    if (accent == cyan) return const Color(0xFF0E7490);
    if (accent == pink) return const Color(0xFFBE185D);
    if (accent == violet) return const Color(0xFF6D28D9);
    return blue;
  }
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
        elevation: 2,
        shadowColor: MaestroColors.text.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MaestroColors.border.withValues(alpha: .7)),
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
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? MaestroColors.primary
                  : MaestroColors.muted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? MaestroColors.primary
                  : MaestroColors.muted,
            )),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: MaestroColors.surface,
        indicatorColor: MaestroColors.subtleBlue,
        minWidth: 84,
        selectedIconTheme: IconThemeData(color: MaestroColors.primary),
        unselectedIconTheme: IconThemeData(color: MaestroColors.muted),
        selectedLabelTextStyle: TextStyle(
            color: MaestroColors.primary, fontWeight: FontWeight.w700),
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

  /// Available for hosts that explicitly opt into dark mode. The legacy
  /// screens still contain fixed light colors, so the app keeps light mode by
  /// default until those screens have been migrated.
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MaestroColors.primary,
        brightness: Brightness.dark,
        primary: const Color(0xFF93B4FF),
        surface: const Color(0xFF1F2937),
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),
      fontFamily: 'Inter',
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: const Color(0xFF1F2937),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        indicatorColor: const Color(0xFF243D70),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF93B4FF)
                  : const Color(0xFF94A3B8),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF93B4FF)
                  : const Color(0xFFCBD5E1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF1F2937),
        indicatorColor: Color(0xFF243D70),
        selectedIconTheme: IconThemeData(color: Color(0xFF93B4FF)),
      ),
    );
  }
}
