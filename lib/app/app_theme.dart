import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const ink = Color(0xFF20251F);
  static const muted = Color(0xFF73786F);
  static const paper = Color(0xFFF5F3ED);
  static const green = Color(0xFF42634F);
  static const sage = Color(0xFFDCE5DA);
  static const line = Color(0xFFE1DFD7);
  static const amber = Color(0xFFF0D798);
}

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.green,
    surface: const Color(0xFFFBFAF6),
  ),
  dividerColor: AppColors.line,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
  ),
);
