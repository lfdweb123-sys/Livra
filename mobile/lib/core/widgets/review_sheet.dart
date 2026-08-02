import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'primary_button.dart';

/// Sheet "Laisser un avis" — n'est jamais affichée avant que le backend
/// confirme que la commande/course est bien livrée/terminée (voir
/// /api/reviews qui revérifie tout de toute façon, jamais fait confiance
/// à l'app seule).
Future<void> showReviewSheet(
  BuildContext context, {
  String? orderId,
  String? rideId,
  required String targetLabel,
}) {
  int rating = 0;
  final commentCtrl = TextEditingController();
  bool submitting = false;

  return showAppBottomSheet(
    context,
    title: 'Comment s\'est passée votre expérience avec $targetLabel ?',
    child: StatefulBuilder(builder: (context, setSheetState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < rating;
              return IconButton(
                onPressed: () => setSheetState(() => rating = i + 1),
                icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.gold, size: 32),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Un commentaire (optionnel)...'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Envoyer mon avis',
            loading: submitting,
            onPressed: rating == 0
                ? null
                : () async {
                    setSheetState(() => submitting = true);
                    try {
                      await ApiClient.instance.post('/api/reviews', data: {
                        if (orderId != null) 'orderId': orderId,
                        if (rideId != null) 'rideId': rideId,
                        'rating': rating,
                        'comment': commentCtrl.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Merci pour votre avis !')),
                        );
                      }
                    } catch (e) {
                      setSheetState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                      }
                    }
                  },
          ),
        ],
      );
    }),
  );
}
