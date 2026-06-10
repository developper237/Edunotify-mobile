export 'app_theme.dart';

import 'package:flutter/material.dart';
import 'app_theme.dart';

extension ThemeContext on BuildContext {
  bool get isDark =>
      Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? AppColors.dark : AppColors.light;

  Color get cardColor =>
      isDark ? AppColors.darkCard : AppColors.lightCard;

  Color get borderColor =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;

  Color get textPrimary =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

  Color get textSecondary =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get textMuted =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;
}