import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/payment/payment_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';

/// Récapitulatif + choix paiement. Le prix affiché ici est indicatif —
/// le total réel vient toujours de la réponse POST /api/orders (serveur).
class OrderCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  OrderCheckoutScreen({super.key, this.initialData});

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  bool _loading = false;
  Map<String, dynamic>? _priceBreakdown;
  String? _orderId;

  Future<void> _createOrder() async {
    setState(() => _loading = true);
    try {
      final position = await LocationService().getCurrentPosition();
      final data = widget.initialData ?? {};
      final res = await ApiClient.instance.post(ApiConstants.orders, data: {
        'type': data['type'] ?? 'colis',
        'vendorId': data['vendorId'],
        'items': data['items'] ?? [],
        'deliveryAddress': {
          'geopoint': {'latitude': position.latitude, 'longitude': position.longitude},
        },
        'pickupAddress': data['type'] == 'colis'
            ? {
                'geopoint': {'latitude': position.latitude, 'longitude': position.longitude},
              }
            : null,
      });
      setState(() {
        _orderId = res['id'];
        _priceBreakdown = Map<String, dynamic>.from(res['priceBreakdown']);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  Future<void> _choosePayment() async {
    if (_orderId == null) return;
    await showAppBottomSheet(
      context,
      title: 'Moyen de paiement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: Text('Mobile Money (FeexPay)'),
            onTap: () => _payFeexpay(),
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: Text('Verzapay (carte / Mobile Money)'),
            onTap: () => _payVerzapay(),
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
            title: Text('Portefeuille Livra'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Couverture complète des réseaux FeexPay V2 gérés côté backend
  // (lib/feexpay.js) — groupés par pays pour l'UI.
  static const Map<String, List<String>> _feexpayCountries = {
    'Bénin': ['mtn', 'moov', 'celtiis_bj', 'coris'],
    'Togo': ['togocom_tg', 'moov_tg'],
    "Côte d'Ivoire": ['mtn_ci', 'moov_ci', 'wave_ci', 'orange_ci'],
    'Congo Brazzaville': ['mtn_cg'],
    'Sénégal': ['orange_sn', 'wave_sn', 'free_sn'],
    'Burkina Faso': ['moov_bf', 'orange_bf', 'wave_bf'],
    'Mali': ['orange_ml', 'mobicash_ml'],
  };
  static const Set<String> _otpRequiredNetworks = {'coris', 'orange_bf'};

  Future<void> _payFeexpay() async {
    Navigator.pop(context);
    final phoneCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    String country = 'Bénin';
    String network = 'mtn';

    await showAppBottomSheet(
      context,
      title: 'Paiement Mobile Money',
      child: StatefulBuilder(builder: (context, setSheetState) {
        final requiresOtp = _otpRequiredNetworks.contains(network);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pays', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            SizedBox(height: 6),
            DropdownButton<String>(
              value: country,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              onChanged: (v) => setSheetState(() {
                country = v!;
                network = _feexpayCountries[country]!.first;
              }),
              items: _feexpayCountries.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            ),
            SizedBox(height: 12),
            Text('Opérateur', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _feexpayCountries[country]!.map((n) {
                final selected = network == n;
                return ChoiceChip(
                  label: Text(n),
                  selected: selected,
                  onSelected: (_) => setSheetState(() => network = n),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Numéro Mobile Money'), keyboardType: TextInputType.phone),
            if (requiresOtp) ...[
              SizedBox(height: 12),
              Text(
                network == 'orange_bf'
                    ? 'Composez #144*4*6*montant# sur votre téléphone Orange BF pour générer le code, puis saisissez-le ci-dessous.'
                    : 'Un code OTP va être envoyé par SMS après le premier envoi — renvoyez ensuite avec le code reçu.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 8),
              TextField(controller: otpCtrl, decoration: InputDecoration(hintText: 'Code OTP (laisser vide au 1er envoi)'), keyboardType: TextInputType.number),
            ],
            SizedBox(height: 16),
            PrimaryButton(
              label: 'Payer',
              onPressed: () async {
                try {
                  await PaymentService().payWithFeexPay(
                    orderId: _orderId,
                    network: network,
                    phoneNumber: phoneCtrl.text.trim(),
                    otp: requiresOtp ? otpCtrl.text.trim() : null,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    if (requiresOtp && otpCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code OTP envoyé — relancez le paiement avec le code reçu par SMS.')),
                      );
                    } else {
                      context.go('/client/tracking/order/$_orderId');
                    }
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _payVerzapay() async {
    Navigator.pop(context);
    try {
      final phone = ''; // à récupérer depuis le profil utilisateur (users/{uid}.phone)
      final res = await PaymentService().payWithVerzapay(orderId: _orderId, phoneNumber: phone);
      // Ouvrir res['checkoutUrl'] via url_launcher, puis rediriger vers le tracking
      if (mounted) context.go('/client/tracking/order/$_orderId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Récapitulatif')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _priceBreakdown == null
              ? Center(child: Text('Erreur de création de commande.'))
              : Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Sous-total', _priceBreakdown!['subtotal']),
                      _row('Frais de livraison', _priceBreakdown!['deliveryFee']),
                      Divider(color: AppColors.divider, height: 32),
                      _row('Total', _priceBreakdown!['total'], bold: true),
                      Spacer(),
                      PrimaryButton(label: 'Choisir le paiement', onPressed: _choosePayment),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, dynamic value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 15);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text('$value XOF', style: style.copyWith(color: bold ? AppColors.gold : null))],
      ),
    );
  }
}
