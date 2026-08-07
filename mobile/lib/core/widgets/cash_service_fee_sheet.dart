import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/friendly_error.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'debounced_button.dart';
import 'phone_number_field.dart';
import '../services/payment/verzapay_checkout_flow.dart';

/// Avant d'autoriser le paiement en espèces à la livraison, le client doit
/// régler les frais de service (5%) numériquement — sinon Livra ne perçoit
/// jamais rien sur ces commandes/courses (le reste est payé en main propre
/// au livreur/vendeur). Une fois réglés, [onSuccess] est appelé (le
/// backend a déjà fixé paymentMethod='cash' automatiquement).
Future<void> showCashServiceFeeSheet(
  BuildContext context, {
  required String payServiceFeeEndpoint, // ex: /api/orders/$id/pay-service-fee
  required num serviceFee,
  required VoidCallback onSuccess,
}) async {
  await showAppBottomSheet(
    context,
    title: 'Frais de service — $serviceFee XOF',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le reste sera réglé en espèces à la livraison. Les frais de service '
          'de Livra ($serviceFee XOF) doivent être payés maintenant.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.phone_android, color: AppColors.gold),
          title: const Text('Mobile Money'),
          onTap: () => _payFeexpay(context, payServiceFeeEndpoint, serviceFee, onSuccess),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.credit_card, color: AppColors.gold),
          title: const Text('Carte bancaire / International'),
          onTap: () async {
            Navigator.of(context).pop();
            await payWithVerzapayFlow(
              context,
              title: 'Frais de service — $serviceFee XOF',
              initiate: (phone) => ApiClient.instance.post(payServiceFeeEndpoint, data: {
                'provider': 'verzapay',
                'phoneNumber': phone,
              }),
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Paiement en cours — confirmation sous peu.')));
                onSuccess();
              },
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
          title: const Text('Portefeuille Livra'),
          onTap: () async {
            Navigator.of(context).pop();
            try {
              await ApiClient.instance.post(payServiceFeeEndpoint, data: {'provider': 'wallet'});
              onSuccess();
            } catch (e) {
              final msg = e.toString().contains('insufficient_balance')
                  ? 'Solde portefeuille insuffisant pour régler les frais de service.'
                  : friendlyError(e);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            }
          },
        ),
      ],
    ),
  );
}

void _payFeexpay(BuildContext context, String endpoint, num serviceFee, VoidCallback onSuccess) {
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
            label: 'Payer $serviceFee XOF',
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Renseignez votre numéro Mobile Money.')));
                return;
              }
              try {
                await ApiClient.instance.post(endpoint, data: {
                  'provider': 'feexpay',
                  'network': network,
                  'phoneNumber': phoneCtrl.text,
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Paiement en cours — confirmation sous peu.')));
                }
                onSuccess();
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
