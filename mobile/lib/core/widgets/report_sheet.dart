import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'primary_button.dart';

const _reasons = {
  'not_received': 'Commande/course non reçue',
  'bad_product': 'Produit non conforme / endommagé',
  'abuse': 'Comportement abusif ou irrespectueux',
  'fraud': 'Fraude ou tentative d\'arnaque',
  'other': 'Autre',
};

/// Ouvre le formulaire de signalement pour un utilisateur donné (vendeur,
/// livreur, ou client — tous les profils peuvent être signalés). [againstUid]
/// doit être l'uid du PROFIL UTILISATEUR (users/{uid}), pas l'id du document
/// vendors/drivers.
Future<void> showReportSheet(
  BuildContext context, {
  required String againstUid,
  required String againstName,
  String? relatedOrderId,
  String? relatedRideId,
}) async {
  String reason = 'not_received';
  final descCtrl = TextEditingController();

  await showAppBottomSheet(
    context,
    title: 'Signaler $againstName',
    child: StatefulBuilder(builder: (context, setSheetState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tout signalement est examiné par notre équipe. En cas de besoin '
            'urgent, contactez directement le support depuis votre profil.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ..._reasons.entries.map((e) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: e.key,
                groupValue: reason,
                onChanged: (v) => setSheetState(() => reason = v!),
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                activeColor: AppColors.gold,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Détails (facultatif)'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Envoyer le signalement',
            onPressed: () async {
              try {
                await ApiClient.instance.post('/api/disputes', data: {
                  'against': againstUid,
                  'reason': reason,
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  if (relatedOrderId != null) 'relatedOrderId': relatedOrderId,
                  if (relatedRideId != null) 'relatedRideId': relatedRideId,
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Signalement envoyé. Notre équipe va l\'examiner.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
          ),
        ],
      );
    }),
  );
}
