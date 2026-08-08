import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/friendly_error.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'primary_button.dart';
import 'debounced_button.dart';
import 'phone_number_field.dart';
import '../services/payment/verzapay_checkout_flow.dart';
import '../constants/boost_tier_colors.dart';

const int _boostPricePerDayXof = 500;

// Miroir des seuils de backend/lib/boostTiers.js — pour informer le
// vendeur/livreur du palier qu'il atteint AVANT de payer.
String _boostTierFor(num pricePaid) {
  if (pricePaid >= 5000) return 'gold';
  if (pricePaid >= 2000) return 'silver';
  return 'bronze';
}

/// Ouvre le flux d'achat d'un boost de profil — le profil apparaît en
/// priorité dans les résultats (drivers/nearby pour livreur/chauffeur/
/// taxi-moto, ou la liste boutiques/restaurants pour un vendeur) pendant
/// la durée choisie.
Future<void> showBoostProfileSheet(
  BuildContext context, {
  required String profileType, // 'driver' | 'vendor'
  required String profileId,
}) async {
  int days = 3;

  await showAppBottomSheet(
    context,
    title: 'Booster mon profil',
    child: StatefulBuilder(builder: (context, setSheetState) {
      final price = _boostPricePerDayXof * days;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre profil apparaît en priorité dans les résultats — vu en premier '
            'par les clients qui commandent ou par les vendeurs qui cherchent un livreur.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Text('Durée', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 3, 7, 14].map((d) {
              final selected = days == d;
              return ChoiceChip(
                label: Text('$d j'),
                selected: selected,
                onSelected: (_) => setSheetState(() => days = d),
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('$price XOF', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: boostTierColor(_boostTierFor(price))),
              const SizedBox(width: 6),
              Text(
                'Palier ${kBoostTierLabelsFr[_boostTierFor(price)]} — plus le budget est élevé, plus vous apparaissez en premier.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Continuer',
            onPressed: () async {
              try {
                final res = await ApiClient.instance.post('/api/boosts', data: {
                  'profileType': profileType,
                  'profileId': profileId,
                  'days': days,
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  await _showBoostPaymentSheet(context, boostId: res['id'], price: price);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            },
          ),
        ],
      );
    }),
  );
}

Future<void> _showBoostPaymentSheet(BuildContext context, {required String boostId, required num price}) async {
  await showAppBottomSheet(
    context,
    title: 'Paiement',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.phone_android, color: AppColors.gold),
          title: const Text('Mobile Money'),
          onTap: () => _payFeexpay(context, boostId, price),
        ),
        ListTile(
          leading: Icon(Icons.credit_card, color: AppColors.gold),
          title: const Text('Carte bancaire / International'),
          onTap: () async {
            Navigator.of(context).pop();
            await payWithVerzapayFlow(
              context,
              initiate: (phone) => ApiClient.instance.post('/api/boosts/$boostId/pay', data: {
                'provider': 'verzapay',
                'phoneNumber': phone,
              }),
              onSuccess: () {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Paiement en cours — le boost démarre après confirmation.')));
                }
              },
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
          title: const Text('Portefeuille Livra'),
          onTap: () async {
            Navigator.of(context).pop();
            try {
              await ApiClient.instance.post('/api/boosts/$boostId/pay', data: {'provider': 'wallet'});
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Boost activé !')));
              }
            } catch (e) {
              final msg = e.toString().contains('insufficient_balance')
                  ? 'Solde portefeuille insuffisant.'
                  : friendlyError(e);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        ),
      ],
    ),
  );
}

void _payFeexpay(BuildContext context, String boostId, num price) {
  Navigator.of(context).pop();
  final phoneCtrl = TextEditingController();
  String network = 'mtn';
  showAppBottomSheet(
    context,
    title: 'Paiement',
    child: StatefulBuilder(builder: (context, setSheetState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: ['mtn', 'moov', 'celtiis_bj', 'coris'].map((n) {
              final selected = network == n;
              return ChoiceChip(
                label: Text(n),
                selected: selected,
                onSelected: (_) => setSheetState(() => network = n),
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          PhoneNumberField(onChanged: (v) => phoneCtrl.text = v),
          const SizedBox(height: 16),
          DebouncedButton(
            label: 'Payer $price XOF',
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Renseignez votre numéro Mobile Money.')));
                return;
              }
              try {
                await ApiClient.instance.post('/api/boosts/$boostId/pay', data: {
                  'provider': 'feexpay',
                  'network': network,
                  'phoneNumber': phoneCtrl.text,
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Paiement en cours — le boost démarre après confirmation.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            },
          ),
        ],
      );
    }),
  );
}
