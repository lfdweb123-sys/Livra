import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/friendly_error.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/phone_number_field.dart';
import '../../../../../core/services/payment/verzapay_checkout_flow.dart';
import '../../../../../core/widgets/debounced_button.dart';

const int _pricePerDayXof = 500;

class VendorAdsScreen extends StatefulWidget {
  const VendorAdsScreen({super.key});
  @override
  State<VendorAdsScreen> createState() => _VendorAdsScreenState();
}

class _VendorAdsScreenState extends State<VendorAdsScreen> {
  String? _vendorId;
  List<ProductModel> _products = [];
  List<dynamic>? _campaigns;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) {
        if (mounted) setState(() { _campaigns = []; _error = "Aucune boutique associée à ce compte."; });
        return;
      }
      setState(() => _vendorId = snap.docs.first.id);
      final productsSnap = await FirebaseFirestore.instance.collection('vendors/$_vendorId/products').where('isAvailable', isEqualTo: true).get();
      setState(() => _products = productsSnap.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
      await _loadCampaigns();
    } catch (e) {
      if (mounted) setState(() { _campaigns = []; _error = 'Erreur de chargement : $e'; });
    }
  }

  String? _error;

  Future<void> _loadCampaigns() async {
    if (_vendorId == null) return;
    try {
      final res = await ApiClient.instance.get('/api/ads/campaigns', query: {'vendorId': _vendorId!});
      if (mounted) setState(() { _campaigns = res['items']; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _campaigns = []; _error = 'Erreur de chargement : $e'; });
    }
  }

  Future<void> _startCampaign() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins un produit à votre catalogue avant de faire de la publicité.')));
      return;
    }
    ProductModel? selectedProduct = _products.first;
    int days = 1;

    await showAppBottomSheet(
      context,
      title: 'Lancer une publicité',
      child: StatefulBuilder(builder: (context, setSheetState) {
        final price = _pricePerDayXof * days;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produit à mettre en avant', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            DropdownButton<ProductModel>(
              value: selectedProduct,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (v) => setSheetState(() => selectedProduct = v),
            ),
            const SizedBox(height: 16),
            Text('Durée (jours)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setSheetState(() => days = days > 1 ? days - 1 : 1)),
                Text('$days jour${days > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setSheetState(() => days++)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$_pricePerDayXof XOF / jour', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$price XOF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold)),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Continuer',
              onPressed: () async {
                if (selectedProduct == null) return;
                Navigator.pop(context);
                await _createAndPay(selectedProduct!, days);
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _createAndPay(ProductModel product, int days) async {
    try {
      final res = await ApiClient.instance.post('/api/ads/campaigns', data: {
        'vendorId': _vendorId,
        'productId': product.id,
        'days': days,
      });
      final campaignId = res['id'];
      await _choosePayment(campaignId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _choosePayment(String campaignId) async {
    await showAppBottomSheet(
      context,
      title: 'Moyen de paiement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
            title: const Text('Portefeuille Livra'),
            onTap: () => _payWith(campaignId, 'wallet'),
          ),
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: const Text('Mobile Money'),
            onTap: () => _payWith(campaignId, 'feexpay'),
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: const Text('Carte bancaire / International'),
            onTap: () => _payWith(campaignId, 'verzapay'),
          ),
        ],
      ),
    );
  }

  Future<void> _payWith(String campaignId, String provider) async {
    Navigator.pop(context);
    if (provider == 'wallet') {
      try {
        await ApiClient.instance.post('/api/ads/campaigns/$campaignId/pay', data: {'provider': 'wallet'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicité lancée !')));
          _loadCampaigns();
        }
      } catch (e) {
        final msg = e.toString().contains('insufficient_balance') ? 'Solde portefeuille insuffisant.' : friendlyError(e);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    if (provider == 'verzapay') {
      // Flux dédié: demande le numéro (obligatoire côté Verzapay) et ouvre
      // le lien de paiement retourné — même logique que partout ailleurs.
      await payWithVerzapayFlow(
        context,
        initiate: (phone) => ApiClient.instance.post('/api/ads/campaigns/$campaignId/pay', data: {
          'provider': 'verzapay',
          'phoneNumber': phone,
        }),
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Paiement en cours — la publicité démarre après confirmation.')));
            _loadCampaigns();
          }
        },
      );
      return;
    }

    // provider == 'feexpay'
    final phoneCtrl = TextEditingController();
    String network = 'mtn';
    await showAppBottomSheet(
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
              label: 'Payer',
              onPressed: () async {
                if (phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renseignez votre numéro Mobile Money.')));
                  return;
                }
                try {
                  await ApiClient.instance.post('/api/ads/campaigns/$campaignId/pay', data: {
                    'provider': provider,
                    'network': network,
                    'phoneNumber': phoneCtrl.text,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement en cours — la publicité démarre après confirmation.')));
                    _loadCampaigns();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicité'), actions: [notificationBellAction(context)]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        onPressed: _startCampaign,
        icon: const Icon(Icons.campaign_rounded, color: Colors.black),
        label: const Text('Lancer une pub', style: TextStyle(color: Colors.black)),
      ),
      body: _campaigns == null
          ? const SkeletonCardList()
          : (_campaigns!.isEmpty && _error != null)
              ? EmptyState(icon: Icons.error_outline_rounded, message: _error!)
              : _campaigns!.isEmpty
              ? const EmptyState(icon: Icons.campaign_outlined, message: 'Aucune campagne pour le moment.\nMettez vos meilleurs produits en avant sur l\'accueil.')
              : RefreshIndicator(
                  onRefresh: _loadCampaigns,
                  color: AppColors.gold,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _campaigns!.length,
                    itemBuilder: (context, i) {
                      final c = _campaigns![i];
                      final statusLabel = {
                        'pending_payment': 'En attente de paiement',
                        'active': 'Active',
                      }[c['status']] ?? c['status'];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(c['productName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: c['status'] == 'active' ? AppColors.success.withOpacity(0.15) : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(statusLabel, style: TextStyle(fontSize: 11, color: c['status'] == 'active' ? AppColors.success : AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${c['days']} jour(s) — ${c['pricePaid']} XOF', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _statChip(Icons.visibility_outlined, '${c['impressions'] ?? 0}', 'vues'),
                                  const SizedBox(width: 16),
                                  _statChip(Icons.touch_app_outlined, '${c['clicks'] ?? 0}', 'clics'),
                                  const SizedBox(width: 16),
                                  _statChip(Icons.shopping_bag_outlined, '${c['conversions'] ?? 0}', 'ventes'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
