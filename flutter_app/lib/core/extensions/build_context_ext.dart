import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

extension AppBuildContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appTextPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  Color get appTextMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  Color get appPrimary =>
      isDark ? AppColors.primaryOnDark : AppColors.primary;

  Color get appSurface =>
      isDark ? AppColors.darkCard : Colors.white;

  Color get appBg =>
      isDark ? AppColors.darkBg : AppColors.bg;

  Color get appBorder =>
      isDark ? AppColors.darkBorder : AppColors.divider;
}
