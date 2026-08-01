import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/notification_bell_action.dart';
import '../../../../core/widgets/phone_number_field.dart';

class WalletScreen extends StatefulWidget {
  WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final res = await ApiClient.instance.get('/api/wallet/$uid');
    setState(() => _wallet = res);
  }

  Future<void> _withdraw() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    await showAppBottomSheet(
      context,
      title: 'Retirer vers Mobile Money',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: amountCtrl, decoration: InputDecoration(hintText: 'Montant (XOF)'), keyboardType: TextInputType.number),
          SizedBox(height: 12),
          PhoneNumberField(onChanged: (v) => phoneCtrl.text = v),
          SizedBox(height: 16),
          PrimaryButton(
            label: 'Confirmer le retrait',
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renseignez votre numéro Mobile Money.')));
                return;
              }
              try {
                await ApiClient.instance.post('/api/wallet/$uid/withdraw', data: {
                  'amount': num.tryParse(amountCtrl.text) ?? 0,
                  'phoneNumber': phoneCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _load();
                }
              } catch (e) {
                final msg = e.toString().contains('insufficient_balance')
                    ? 'Solde insuffisant sur votre portefeuille.'
                    : 'Erreur lors du retrait. Réessayez dans un instant.';
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deposit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final amountCtrl = TextEditingController();
    await showAppBottomSheet(
      context,
      title: 'Déposer sur mon portefeuille',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: amountCtrl, decoration: InputDecoration(hintText: 'Montant (XOF)'), keyboardType: TextInputType.number),
          SizedBox(height: 16),
          PrimaryButton(
            label: 'Continuer',
            onPressed: () {
              final amount = num.tryParse(amountCtrl.text) ?? 0;
              if (amount < 100) return;
              Navigator.pop(context);
              _chooseDepositMethod(uid, amount);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDepositMethod(String uid, num amount) async {
    await showAppBottomSheet(
      context,
      title: 'Moyen de paiement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: Text('Mobile Money'),
            onTap: () => _depositFeexpay(uid, amount),
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: Text('Carte bancaire / International'),
            onTap: () => _depositVerzapay(uid, amount),
          ),
        ],
      ),
    );
  }

  Future<void> _depositFeexpay(String uid, num amount) async {
    Navigator.pop(context);
    final phoneCtrl = TextEditingController();
    String network = 'mtn';
    await showAppBottomSheet(
      context,
      title: 'Paiement Mobile Money',
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
            SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Numéro Mobile Money'), keyboardType: TextInputType.phone),
            SizedBox(height: 16),
            PrimaryButton(
              label: 'Payer $amount XOF',
              onPressed: () async {
                try {
                  await ApiClient.instance.post('/api/wallet/$uid/deposit', data: {
                    'amount': amount,
                    'provider': 'feexpay',
                    'network': network,
                    'phoneNumber': phoneCtrl.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dépôt en cours — validez sur votre téléphone.')),
                    );
                    _load();
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

  Future<void> _depositVerzapay(String uid, num amount) async {
    Navigator.pop(context);
    try {
      await ApiClient.instance.post('/api/wallet/$uid/deposit', data: {
        'amount': amount,
        'provider': 'verzapay',
        'phoneNumber': '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dépôt en cours de traitement.')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Portefeuille Livra'), actions: [notificationBellAction(context)]),
      body: swipeableTab(context: context, currentIndex: 2, child: _wallet == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.surface, AppColors.surfaceElevated]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde', style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      Text('${_wallet!['balance']} XOF', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: PrimaryButton(label: 'Déposer', onPressed: _deposit)),
                          SizedBox(width: 12),
                          Expanded(child: PrimaryButton(label: 'Retirer', onPressed: _withdraw, outlined: true)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...List<Widget>.from((_wallet!['transactions'] as List).map((t) => Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(t['type'] == 'credit' ? Icons.arrow_downward : Icons.arrow_upward, color: t['type'] == 'credit' ? AppColors.success : AppColors.danger),
                        title: Text(t['reason'] ?? ''),
                        trailing: Text('${t['amount']} XOF'),
                      ),
                    ))),
              ],
            ),
            ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
