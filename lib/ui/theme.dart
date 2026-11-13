import 'package:flutter/material.dart';

/// Colores del diseño (Mockups · Registro y preferencias, Sprint 1).
abstract final class AppColors {
  static const background = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C1B19);
  static const textMuted = Color(0xFF5F5A52);
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1F5C3A);
  static const primaryLight = Color(0xFFE3F1E8);
  static const border = Color(0xFFE3DED5);
  static const borderStrong = Color(0xFF8C857A);
  static const googleBorder = Color(0xFF747775);
  static const error = Color(0xFFB3261E);
  static const warningBg = Color(0xFFFFF4E0);
  static const warningText = Color(0xFF8A5300);
  static const avoidBg = Color(0xFFEDE9E2);
  static const scrim = Color(0x8C1C1B19); // 55 % de opacidad
}

/// Tipografías del diseño. Si los archivos de fuente no están en assets/fonts,
/// Flutter usa la fuente del sistema sin dar error (ver README del sprint).
abstract final class AppFonts {
  static const body = 'Inter';
  static const display = 'PlusJakartaSans';
}

abstract final class AppText {
  static const h1 = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const hero = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const h2 = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const body = TextStyle(fontSize: 16, height: 1.5, color: AppColors.text);
  static const bodyMuted = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textMuted);
  static const small = TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.text);
  static const smallMuted = TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.textMuted);
  static const label = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: AppColors.text);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.background,
    error: AppColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.body,
    textTheme: const TextTheme(
      bodyMedium: AppText.body,
      bodyLarge: AppText.body,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface,
      ),
      side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: AppColors.primary,
      inactiveTrackColor: AppColors.border,
    ),
  );
}
