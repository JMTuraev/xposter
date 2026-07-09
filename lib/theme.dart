import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// «Claude Light» dizayn-tizim tokenlari.
/// design-system.md dagi paletra bilan bir xil.
class AppColors {
  static const bg = Color(0xFFFAF9F5);
  static const bgSecondary = Color(0xFFF0EEE6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHover = Color(0xFFF5F4EE);
  static const border = Color(0xFFE3E0D5);
  static const borderStrong = Color(0xFFD1CEC2);

  static const text = Color(0xFF141413);
  static const textSecondary = Color(0xFF6E6B63);
  static const textTertiary = Color(0xFF9C9A92);

  static const accent = Color(0xFFD97757);
  static const accentHover = Color(0xFFC96442);
  static const accentSoft = Color(0xFFF6E9E2);

  static const success = Color(0xFF788C5D);
  static const successSoft = Color(0xFFEDF1E6);
  static const danger = Color(0xFFBF4D43);
  static const dangerSoft = Color(0xFFF9E9E7);
  static const warning = Color(0xFFC9944A);
  static const warningSoft = Color(0xFFF8EFDF);
  static const info = Color(0xFF5B8DEF);

  /// POS kassa qora paneli (Poster uslubi — light temadan istisno).
  static const posDark = Color(0xFF2D2C28);
}

class AppRadius {
  static const card = 16.0;
  static const btn = 12.0;
  static const input = 12.0;
  static const sheet = 20.0;
  static const pill = 999.0;
}

/// Yumshoq karta soyasi.
const kSoftShadow = [
  BoxShadow(color: Color(0x0F141413), blurRadius: 3, offset: Offset(0, 1)),
];

class AppTheme {
  /// UI shrifti — Inter.
  static TextStyle sans({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Sarlavha / KPI raqamlar — serif (Lora).
  static TextStyle serif({
    double size = 28,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.text,
    double? height,
  }) =>
      GoogleFonts.lora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.text,
      ),
    );
  }
}
