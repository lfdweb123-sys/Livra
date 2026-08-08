import 'package:flutter/material.dart';

/// Couleur et libellé selon le palier de boost renvoyé par le backend
/// ('gold' | 'silver' | 'bronze') — voir backend/lib/boostTiers.js pour
/// les seuils exacts (budget dépensé). Un profil ayant payé davantage
/// pour son boost doit être visuellement plus mis en avant.
const Map<String, Color> kBoostTierColors = {
  'gold': Color(0xFFD4AF37),
  'silver': Color(0xFFB8C0C8),
  'bronze': Color(0xFFCD7F32),
};

const Map<String, String> kBoostTierLabelsFr = {
  'gold': 'Or',
  'silver': 'Argent',
  'bronze': 'Bronze',
};

Color boostTierColor(String? tier) => kBoostTierColors[tier] ?? const Color(0xFFCD7F32);
