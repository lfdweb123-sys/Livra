import 'package:flutter/material.dart';
import 'app_colors_dark.dart';
import 'app_colors_light.dart';
import 'theme_controller.dart';

/// Facade : chaque écran utilise `AppColors.gold`, `AppColors.surface`, etc.
/// sans jamais savoir si on est en clair ou en sombre. La bascule se fait
/// uniquement ici, en lisant ThemeController — aucun écran n'a besoin d'être
/// modifié pour supporter les deux thèmes.
class AppColors {
  AppColors._();

  static bool get _light => ThemeController.instance.isLight;

  static Color get background => _light ? AppColorsLight.background : AppColorsDark.background;
  static Color get surface => _light ? AppColorsLight.surface : AppColorsDark.surface;
  static Color get surfaceElevated => _light ? AppColorsLight.surfaceElevated : AppColorsDark.surfaceElevated;
  static Color get gold => _light ? AppColorsLight.gold : AppColorsDark.gold;
  static Color get goldSoft => _light ? AppColorsLight.goldSoft : AppColorsDark.goldSoft;
  static Color get textPrimary => _light ? AppColorsLight.textPrimary : AppColorsDark.textPrimary;
  static Color get textSecondary => _light ? AppColorsLight.textSecondary : AppColorsDark.textSecondary;
  static Color get success => _light ? AppColorsLight.success : AppColorsDark.success;
  static Color get danger => _light ? AppColorsLight.danger : AppColorsDark.danger;
  static Color get warning => _light ? AppColorsLight.warning : AppColorsDark.warning;
  static Color get divider => _light ? AppColorsLight.divider : AppColorsDark.divider;
}
