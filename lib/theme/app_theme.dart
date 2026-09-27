import 'package:flutter/material.dart';

/// Colors pulled to match the NEXUS NETWORK logo: deep teal-black
/// background, neon cyan glow accent, and cool silver/steel for secondary
/// text and metallic UI elements.
class AppColors {
  static const accent = Color(0xFF2DD6EA); // neon cyan from the shield/globe
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const silver = Color(0xFF9FB4BC); // metallic gray from the shield

  static const darkBg = Color(0xFF0A1A1D); // deep teal-black background
  static const darkSurface = Color(0xFF102A2E); // teal-tinted card surface
  static const darkSurfaceAlt = Color(0xFF15373C);

  static const lightBg = Color(0xFFF2F6F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFE7EEEE);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        error: AppColors.danger,
      ),
      cardColor: AppColors.darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.accent : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.5)
                : null),
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF0E7C8C),
        secondary: const Color(0xFF0E7C8C),
        surface: AppColors.lightSurface,
        error: AppColors.danger,
      ),
      cardColor: AppColors.lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.black87,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: Color(0xFF0E7C8C),
        unselectedItemColor: Colors.black38,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    );
  }
}
