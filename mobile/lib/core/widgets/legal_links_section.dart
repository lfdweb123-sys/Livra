import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../constants/api_constants.dart';

const _legalLinks = [
  {'title': "Conditions d'utilisation", 'path': '/legal/cgu'},
  {'title': 'Politique de confidentialité', 'path': '/legal/confidentialite'},
  {'title': 'Conditions de vente', 'path': '/legal/vente'},
  {'title': 'Mentions légales', 'path': '/legal/mentions'},
];

/// Section "Informations légales" à afficher sur chaque page de profil
/// (client, vendeur, livreur) — ouvre chaque page en WebView intégrée.
class LegalLinksSection extends StatelessWidget {
  const LegalLinksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: _legalLinks
            .map((l) => ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(Icons.description_outlined, color: AppColors.textSecondary),
                  title: Text(l['title']!),
                  trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => context.push('/browser', extra: {
                    'url': '${ApiConstants.siteUrl}${l['path']}',
                    'title': l['title'],
                  }),
                ))
            .toList(),
      ),
    );
  }
}
