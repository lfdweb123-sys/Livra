import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/payment/payment_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/address_picker_sheet.dart';
import '../../../../../core/services/payment/verzapay_checkout_flow.dart';

/// Étape 1 : confirmation/choix des adresses (livraison, + collecte si colis)
/// — automatique par GPS par défaut, mais toujours modifiable manuellement.
/// Étape 2 : récapitulatif + choix paiement, une fois la commande créée
/// côté serveur (le prix affiché vient toujours de la réponse API, jamais
/// calculé côté client).
class OrderCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const OrderCheckoutScreen({super.key, this.initialData});

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  bool _loadingAddress = true;
  bool _creatingOrder = false;
  Map<String, dynamic>? _priceBreakdown;
  String? _orderId;

  PickedAddress? _deliveryAddress;
  PickedAddress? _pickupAddress;

  bool get _isColis => (widget.initialData ?? {})['type'] == 'colis';

  @override
  void initState() {
    super.initState();
    _detectDefaultAddresses();
  }

  Future<void> _detectDefaultAddresses() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      final auto = PickedAddress(lat: pos.latitude, lng: pos.longitude, label: 'Ma position actuelle');
      setState(() {
        _deliveryAddress = auto;
        if (_isColis) _pickupAddress = auto;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Localisation indisponible : $e')));
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _editDeliveryAddress() async {
    final result = await showAddressPicker(context, title: 'Adresse de livraison');
    if (result != null) setState(() => _deliveryAddress = result);
  }

  Future<void> _editPickupAddress() async {
    final result = await showAddressPicker(context, title: 'Adresse de collecte du colis');
    if (result != null) setState(() => _pickupAddress = result);
  }

  Future<void> _createOrder() async {
    if (_deliveryAddress == null || (_isColis && _pickupAddress == null)) return;
    setState(() => _creatingOrder = true);
    try {
      final data = widget.initialData ?? {};
      final res = await ApiClient.instance.post(ApiConstants.orders, data: {
        'type': data['type'] ?? 'colis',
        'vendorId': data['vendorId'],
        'items': data['items'] ?? [],
        'deliveryAddress': {
          'geopoint': {'latitude': _deliveryAddress!.lat, 'longitude': _deliveryAddress!.lng},
          'label': _deliveryAddress!.label,
        },
        'pickupAddress': _isColis
            ? {
                'geopoint': {'latitude': _pickupAddress!.lat, 'longitude': _pickupAddress!.lng},
                'label': _pickupAddress!.label,
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
      if (mounted) setState(() => _creatingOrder = false);
    }
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
            title: Text('Mobile Money'),
            onTap: () => _payFeexpay(),
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: Text('Carte bancaire / International'),
            onTap: () => _payVerzapay(),
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
            title: Text('Portefeuille Livra'),
            onTap: _payWallet,
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined, color: AppColors.gold),
            title: Text('Espèces à la livraison'),
            subtitle: Text('Payez directement au livreur', style: TextStyle(fontSize: 12)),
            onTap: _payCash,
          ),
        ],
      ),
    );
  }

  Future<void> _payWallet() async {
    Navigator.pop(context);
    try {
      await ApiClient.instance.patch('/api/orders/$_orderId', data: {'paymentMethod': 'wallet'});
      if (mounted) context.go('/client/tracking/order/$_orderId');
    } catch (e) {
      final msg = e.toString().contains('insufficient_balance')
          ? 'Solde insuffisant sur votre portefeuille Livra. Déposez des fonds ou choisissez un autre moyen de paiement.'
          : 'Erreur: $e';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _payCash() async {
    Navigator.pop(context);
    try {
      await ApiClient.instance.patch('/api/orders/$_orderId', data: {'paymentMethod': 'cash'});
      if (mounted) context.go('/client/tracking/order/$_orderId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

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
  static const Map<String, String> _countryCallingCode = {
    'Bénin': '+229',
    'Togo': '+228',
    "Côte d'Ivoire": '+225',
    'Congo Brazzaville': '+242',
    'Sénégal': '+221',
    'Burkina Faso': '+226',
    'Mali': '+223',
  };

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
                  labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            Text('Numéro de téléphone', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14)),
                  child: Text(_countryCallingCode[country]!, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Numéro complet (avec le 0)'), keyboardType: TextInputType.phone),
                ),
              ],
            ),
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
                    phoneNumber: '${_countryCallingCode[country]}${phoneCtrl.text.trim()}',
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
    await payWithVerzapayFlow(
      context,
      initiate: (phone) => PaymentService().payWithVerzapay(orderId: _orderId, phoneNumber: phone),
      onSuccess: () {
        if (mounted) context.go('/client/tracking/order/$_orderId');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Étape 2 : commande créée, on affiche le récap + paiement.
    if (_priceBreakdown != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Récapitulatif')),
        body: Padding(
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

    // Étape 1 : choix/confirmation des adresses.
    return Scaffold(
      appBar: AppBar(title: Text('Adresse de livraison')),
      body: _loadingAddress
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isColis) ...[
                    Text('Adresse de collecte', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    SizedBox(height: 8),
                    _addressCard(_pickupAddress?.label ?? '—', _editPickupAddress),
                    SizedBox(height: 20),
                  ],
                  Text('Adresse de livraison', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  SizedBox(height: 8),
                  _addressCard(_deliveryAddress?.label ?? '—', _editDeliveryAddress),
                  Spacer(),
                  PrimaryButton(
                    label: 'Continuer',
                    onPressed: _deliveryAddress == null || (_isColis && _pickupAddress == null) ? null : _createOrder,
                    loading: _creatingOrder,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _addressCard(String label, VoidCallback onEdit) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: AppColors.gold),
            SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
            Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
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
