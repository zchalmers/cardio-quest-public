import 'package:flutter/material.dart';

import 'palette.dart';

abstract final class CardioQuestTheme {
  static ThemeData get dark {
    final ColorScheme colors =
        ColorScheme.fromSeed(
          seedColor: AppColors.mint,
          brightness: Brightness.dark,
          surface: AppColors.ink,
        ).copyWith(
          primary: AppColors.mint,
          secondary: AppColors.gold,
          error: AppColors.coral,
          surface: AppColors.ink,
          onSurface: AppColors.text,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.ink,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.text,
          fontSize: 52,
          fontWeight: FontWeight.w900,
          height: 0.98,
          letterSpacing: -2,
        ),
        headlineLarge: TextStyle(
          color: AppColors.text,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: Color(0x4465F2D0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.mint,
        inactiveTrackColor: Color(0x335BF0D0),
        thumbColor: Colors.white,
        overlayColor: Color(0x3365F2D0),
        trackHeight: 6,
      ),
    );
  }
}
