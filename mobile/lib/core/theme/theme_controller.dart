import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un seul point de vérité pour le mode clair/sombre, persisté localement.
/// AppColors (facade) lit `ThemeController.instance.mode.value` à chaque
/// accès : basculer le thème ici retinte automatiquement tous les écrans
/// qui utilisent `AppColors.xxx`, sans avoir à toucher chaque fichier.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'livra_theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    mode.value = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.value == ThemeMode.light ? 'light' : 'dark');
  }

  bool get isLight => mode.value == ThemeMode.light;
}
