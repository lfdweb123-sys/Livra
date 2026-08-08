import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/constants/wallet_reason_labels.dart';

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
    if (mounted) setState(() => _wallet = res);
  }

  @override
  Widget build(BuildContext context) {
    final pendingBalance = (_wallet?['pendingBalance'] ?? 0) as num;
    return Scaffold(
      appBar: AppBar(title: Text('Mes gains'), actions: [notificationBellAction(context)]),
      body: swipeableTab(context: context, currentIndex: 1, child: _wallet == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView(
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
                      Text('${_wallet!['balance'] ?? 0} XOF', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      // BUG CORRIGE: cet ecran n'affichait JAMAIS pendingBalance
                      // (les gains encore bloques 3 jours) - un livreur venant
                      // de terminer une livraison voyait "0 XOF" sans la
                      // moindre explication, comme si l'argent avait disparu.
                      if (pendingBalance > 0) ...[
                        SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_clock_outlined, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$pendingBalance XOF en attente — disponibles sous 3 jours après chaque livraison/course, le temps de traiter une éventuelle réclamation.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 16),
                      PrimaryButton(label: 'Retirer', onPressed: () => context.push('/wallet')),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if ((_wallet!['transactions'] as List).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('Aucune transaction pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ...List<Widget>.from((_wallet!['transactions'] as List).map((t) {
                  final isCredit = t['type'] == 'credit';
                  final isPending = t['matured'] == false;
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isCredit ? AppColors.success : AppColors.danger,
                      ),
                      // BUG CORRIGE: affichait le code brut du backend
                      // (ex: "delivery_earnings") au lieu d'un vrai texte.
                      title: Text(walletReasonLabelFr(t['reason'])),
                      subtitle: isPending ? Text('En attente (3 jours)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)) : null,
                      trailing: Text(
                        '${isCredit ? '+' : '-'}${t['amount']} XOF',
                        style: TextStyle(fontWeight: FontWeight.w600, color: isCredit ? AppColors.success : AppColors.textPrimary),
                      ),
                    ),
                  );
                })),
              ],
            ),
            ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
