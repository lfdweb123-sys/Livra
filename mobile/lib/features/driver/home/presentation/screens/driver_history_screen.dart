import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/constants/status_labels.dart';

/// Historique complet — toutes les commandes et courses jamais confiées à
/// ce livreur, quel que soit leur statut (en cours ou terminées). Rien ne
/// disparaît jamais de cette liste : elle sert de preuve permanente, aussi
/// bien pour une livraison en cours que pour une déjà terminée depuis
/// longtemps.
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});
  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ordersRes = await ApiClient.instance.get('/api/orders', query: {'limit': 100});
      final ridesRes = await ApiClient.instance.get('/api/rides', query: {'limit': 100});
      final orders = (ordersRes['items'] as List).map((e) => {...e as Map<String, dynamic>, '_kind': 'order'});
      final rides = (ridesRes['items'] as List).map((e) => {...e as Map<String, dynamic>, '_kind': 'ride'});
      final merged = [...orders, ...rides];
      merged.sort((a, b) {
        final ta = a['createdAt']?['_seconds'] ?? 0;
        final tb = b['createdAt']?['_seconds'] ?? 0;
        return (tb as num).compareTo(ta as num);
      });
      if (mounted) setState(() { _items = merged; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _items = []; _error = 'Impossible de charger votre historique. Tirez pour réessayer.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon historique')),
      body: _items == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: _items!.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: _error ?? "Aucune commande ni course pour l'instant.",
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items!.length,
                      itemBuilder: (context, i) {
                        final item = _items![i];
                        final isRide = item['_kind'] == 'ride';
                        final status = item['status'] ?? '';
                        final label = statusLabelFr(status);
                        final amount = isRide ? item['price'] : item['priceBreakdown']?['total'];
                        final title = isRide ? 'Course ${item['vehicleType'] ?? ''}' : 'Commande ${item['type'] ?? ''}';
                        final isTerminal = status == 'delivered' || status == 'completed' || status == 'cancelled';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              isRide ? Icons.two_wheeler_rounded : Icons.inventory_2_outlined,
                              color: isTerminal ? AppColors.textSecondary : AppColors.gold,
                            ),
                            title: Text(title),
                            subtitle: Text('${amount ?? '-'} XOF — $label'),
                            onTap: isTerminal
                                ? () => context.push('/order-detail/${isRide ? 'ride' : 'order'}/${item['id']}')
                                : () => context.push(isRide
                                    ? '/driver/navigation/ride/${item['id']}'
                                    : '/driver/navigation/order/${item['id']}'),
                            trailing: !isTerminal
                                ? TextButton(
                                    onPressed: () => context.push(isRide
                                        ? '/driver/navigation/ride/${item['id']}'
                                        : '/driver/navigation/order/${item['id']}'),
                                    child: const Text('Continuer'),
                                  )
                                : Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
