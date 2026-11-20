import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF7B2C2F);
  static const Color card = Color(0xFF8C3A3D);
  static const Color accent = Color(0xFFEEC4B4);
  static const Color textPrimary = Colors.white;
  static const Color muted = Color(0xFFE7DADA);
  static const Color chip = Color(0xFF9C4A4E);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.card,
      brightness: Brightness.dark,
    ).copyWith(
      background: AppColors.background,
      surface: AppColors.card,
      primary: AppColors.accent,
      onPrimary: Colors.black,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    cardColor: AppColors.card,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.chip,
      labelStyle: TextStyle(color: AppColors.textPrimary),
      shape: StadiumBorder(),
      side: BorderSide.none,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}







