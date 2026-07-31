import 'package:flutter/material.dart';

/// Miroir clair de AppColors — mêmes rôles sémantiques, jamais référencé
/// directement dans les écrans (qui utilisent Theme.of(context)), seulement
/// depuis app_theme.dart.
class AppColorsLight {
  AppColorsLight._();

  static const Color background = Color(0xFFFAF9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF1EFE9);
  static const Color gold = Color(0xFFB8912E);
  static const Color goldSoft = Color(0xFFD9BB6E);
  static const Color textPrimary = Color(0xFF17171A);
  static const Color textSecondary = Color(0xFF6B6B6F);
  static const Color success = Color(0xFF1E9A63);
  static const Color danger = Color(0xFFD3373C);
  static const Color warning = Color(0xFFC98416);
  static const Color divider = Color(0xFFE4E1D8);
}
