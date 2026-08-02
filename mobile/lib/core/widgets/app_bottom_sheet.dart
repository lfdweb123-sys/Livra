import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Actions rapides en bottom sheet plutôt que nouvelle page (choix véhicule,
/// confirmation commande, choix moyen de paiement…).
Future<T?> showAppBottomSheet<T>(BuildContext context, {required Widget child, String? title}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          // Fond adapté au thème courant (clair/sombre) — un fond figé en
          // sombre rendait le texte des ListTile illisible en mode clair
          // (texte sombre du thème sur fond sombre forcé).
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (title != null) ...[
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}
