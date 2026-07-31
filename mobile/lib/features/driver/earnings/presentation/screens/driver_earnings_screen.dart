import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';

class DriverEarningsScreen extends StatefulWidget {
  DriverEarningsScreen({super.key});
  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes gains')),
      body: _wallet == null
          ? SkeletonCardList()
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde disponible', style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      Text('${_wallet!['balance']} XOF', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.gold)),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
