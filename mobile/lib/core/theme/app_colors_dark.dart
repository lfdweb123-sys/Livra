import 'package:flutter/material.dart';

/// Palette "Noir/Orange" — couleurs reprises directement du logo Livra
/// (le pictogramme pin+camion). Les noms de variables `gold`/`goldSoft` sont
/// conservés pour ne pas casser tout le code existant, mais portent
/// désormais l'orange du logo, plus le jaune doré d'avant.
class AppColorsDark {
  AppColorsDark._();

  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF17171A);
  static const Color surfaceElevated = Color(0xFF212125);
  static const Color gold = Color(0xFFF2660B);
  static const Color goldSoft = Color(0xFFFF9A44);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9B9B9F);
  static const Color success = Color(0xFF33C481);
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);
  static const Color divider = Color(0xFF2A2A2E);
}
