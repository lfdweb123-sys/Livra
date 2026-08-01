import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_bottom_nav.dart';

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
          TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Numéro Mobile Money'), keyboardType: TextInputType.phone),
          SizedBox(height: 16),
          PrimaryButton(
            label: 'Confirmer le retrait',
            onPressed: () async {
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Portefeuille Livra')),
      body: _wallet == null
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
                      PrimaryButton(label: 'Retirer', onPressed: _withdraw),
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
