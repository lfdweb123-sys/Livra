import 'package:flutter/material.dart';

/// Logo Livra (pictogramme pin+camion). Utiliser [full] pour le logo complet
/// avec texte "Livra" + tagline (écrans d'accueil/splash), ou la version
/// icône seule (par défaut) pour les headers/app bars compacts.
class AppLogo extends StatelessWidget {
  final double size;
  final bool full;

  const AppLogo({super.key, this.size = 64, this.full = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      full ? 'assets/images/livra_logo_full.png' : 'assets/images/livra_icon_mark.png',
      height: size,
      width: full ? null : size,
      fit: BoxFit.contain,
    );
  }
}
