import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';

/// Icône de partage qui ouvre le sélecteur natif du téléphone — l'utilisateur
/// choisit lui-même l'application (WhatsApp, Facebook, Instagram, Telegram,
/// SMS, email...), ce qui couvre "n'importe quel réseau social" sans avoir à
/// intégrer chaque réseau un par un.
///
/// NOTE: l'app n'a pas encore de page web publique par produit (le backend
/// est un panneau d'administration, pas un site vitrine), donc le partage
/// se fait pour l'instant en texte descriptif plutôt qu'en lien cliquable
/// menant directement à la fiche produit dans un navigateur.
class ShareButton extends StatelessWidget {
  final String productName;
  final num price;
  final String? vendorName;
  final double size;

  const ShareButton({
    super.key,
    required this.productName,
    required this.price,
    this.vendorName,
    this.size = 20,
  });

  void _share(BuildContext context) {
    final vendorPart = vendorName != null ? ' chez $vendorName' : '';
    final text = '$productName — $price XOF$vendorPart.\n'
        'Découvert sur Livra, commandez-le directement dans l\'app !';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      text,
      subject: productName,
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.share_outlined, color: AppColors.textSecondary, size: size),
      tooltip: 'Partager',
      onPressed: () => _share(context),
    );
  }
}
