import 'package:flutter/material.dart';
import '../phone_number_cache.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/phone_number_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/payment_webview_screen.dart';

/// Flux Verzapay commun à tous les écrans de paiement (dépôt portefeuille,
/// paiement commande, paiement course, paiement publicité vendeur).
///
/// Verzapay REFUSE systématiquement de créer un lien de paiement si
/// `customer_phone` est vide ou fait moins de 6 caractères (erreur 400
/// "Donnée invalide (customer_phone)"). On demande donc toujours le
/// numéro ici — pré-rempli depuis le dernier numéro utilisé — avant
/// d'appeler [initiate]. Une fois le lien de paiement (`checkoutUrl`)
/// reçu, on l'ouvre dans le navigateur externe (Verzapay = carte
/// bancaire / paiement international, pas un push USSD comme Feexpay).
Future<void> payWithVerzapayFlow(
  BuildContext context, {
  required Future<Map<String, dynamic>> Function(String phoneNumber) initiate,
  VoidCallback? onSuccess,
  String title = 'Paiement par carte / International',
}) async {
  final phoneCtrl = TextEditingController();
  final cachedPhone = await PhoneNumberCache().load();
  if (cachedPhone != null) phoneCtrl.text = cachedPhone;
  bool submitting = false;

  await showAppBottomSheet(
    context,
    title: title,
    child: StatefulBuilder(builder: (sheetContext, setSheetState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Numéro requis par Verzapay pour générer le lien de paiement.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 8),
          PhoneNumberField(
            initialValue: cachedPhone,
            onChanged: (v) => phoneCtrl.text = v,
          ),
          SizedBox(height: 16),
          PrimaryButton(
            label: 'Continuer vers le paiement',
            loading: submitting,
            onPressed: submitting
                ? null
                : () async {
                    final phone = phoneCtrl.text.trim();
                    if (phone.length < 6) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                          content: Text('Renseignez un numéro de téléphone valide.')));
                      return;
                    }
                    setSheetState(() => submitting = true);
                    try {
                      final result = await initiate(phone);
                      await PhoneNumberCache().save(phone);
                      final checkoutUrl = result['checkoutUrl']?.toString();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (checkoutUrl != null && checkoutUrl.isNotEmpty && sheetContext.mounted) {
                        // Ouvre le paiement DANS l'app (WebView), jamais dans
                        // Chrome — sortir de l'app en plein paiement fait
                        // fuir les clients.
                        await Navigator.of(sheetContext).push(MaterialPageRoute(
                          builder: (_) => PaymentWebviewScreen(url: checkoutUrl, title: 'Paiement Verzapay'),
                        ));
                      }
                      onSuccess?.call();
                    } catch (e) {
                      setSheetState(() => submitting = false);
                      final raw = e.toString();
                      final msg = raw.contains('phone_required')
                          ? 'Numéro de téléphone requis pour ce paiement.'
                          : 'Erreur lors de la création du paiement. Réessayez.';
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      }
                    }
                  },
          ),
        ],
      );
    }),
  );
}
