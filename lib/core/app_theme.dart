import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

class AppColors {
  // Couleurs fixes (identiques dans les deux thèmes)
  static const cyan    = Color(0xFF06B6D4);
  static const green   = Color(0xFF10B981);
  static const orange  = Color(0xFFF97316);
  static const violet  = Color(0xFF8B5CF6);
  static const blue    = Color(0xFF3B82F6);
  static const red     = Color(0xFFF43F5E);
  static const yellow  = Color(0xFFF59E0B);

  // Thème sombre
  static const dark       = Color(0xFF0B0E1C);
  static const darkCard   = Color(0xFF131629);
  static const darkBorder = Color(0xFF1E2235);
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF64748B);

  // Thème clair
  static const light        = Color(0xFFF8FAFC);
  static const lightCard    = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFE2E8F0);
  static const lightTextPrimary   = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted     = Color(0xFF94A3B8);

  static Color forRole(String role) {
    switch (role) {
      case 'super_admin':      return violet;
      case 'admin':            return blue;
      case 'chef_departement': return green;
      case 'delegue':          return orange;
      case 'etudiant':         return cyan;
      default:                 return cyan;
    }
  }
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      surface: AppColors.darkCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.dark,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkCard,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          color: selected ? AppColors.cyan : AppColors.textMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.cyan : AppColors.textMuted,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.dark,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.cyan,
      labelColor: AppColors.cyan,
      unselectedLabelColor: AppColors.textMuted,
    ),
  );

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.cyan,
      surface: AppColors.lightCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.light,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightCard,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          color: selected ? AppColors.cyan : AppColors.lightTextMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.cyan : AppColors.lightTextMuted,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightCard,
      hintStyle: TextStyle(
          color: AppColors.lightTextMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
    ),
    dividerTheme:
    const DividerThemeData(color: AppColors.lightBorder),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.cyan,
      labelColor: AppColors.cyan,
      unselectedLabelColor: AppColors.lightTextMuted,
    ),
    cardColor: AppColors.lightCard,
  );
}