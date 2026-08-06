import 'package:flutter/material.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/driver_picker.dart';

class VendorOrdersScreen extends StatefulWidget {
  VendorOrdersScreen({super.key});
  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  List<dynamic>? _orders;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.get(ApiConstants.orders, query: {'limit': 30});
    setState(() => _orders = res['items']);
  }

  Future<void> _advance(String id, String nextStatus, Map order) async {
    String? preferredDriverId;
    if (nextStatus == 'picked_up') {
      // Le restaurant peut choisir un livreur actif précis pour venir
      // récupérer la commande, ou ne rien choisir (livreur hors
      // application, ou laisser l'appli proposer la commande à tous les
      // livreurs à proximité comme avant).
      final geopoint = order['matchPosition']?['geopoint'];
      if (geopoint != null) {
        preferredDriverId = await pickDriver(
          context,
          lat: (geopoint['latitude'] as num).toDouble(),
          lng: (geopoint['longitude'] as num).toDouble(),
          vehicleType: 'coursier',
          title: 'Choisir un livreur',
        );
      }
    }
    await ApiClient.instance.patch('/api/orders/$id', data: {
      'status': nextStatus,
      if (preferredDriverId != null) 'preferredDriverId': preferredDriverId,
    });
    _load();
  }

  static const _next = {'pending': 'accepted', 'accepted': 'preparing', 'preparing': 'picked_up'};
  static const _statusLabelsFr = {
    'pending': 'En attente',
    'accepted': 'Acceptée',
    'preparing': 'En préparation',
    'picked_up': 'Prête, en attente de collecte',
    'delivering': 'En livraison',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commandes reçues'), actions: [notificationBellAction(context)]),
      body: swipeableTab(context: context, currentIndex: 1, child: RefreshIndicator(
        onRefresh: _load,
        child: _orders == null
            ? SkeletonCardList()
            : _orders!.isEmpty
                ? EmptyState(icon: Icons.receipt_long_outlined, message: 'Aucune commande pour le moment.')
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _orders!.length,
                    itemBuilder: (context, i) {
                      final o = _orders![i];
                      final next = _next[o['status']];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Commande ${o['id'].toString().substring(0, 6)}', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${o['priceBreakdown']?['subtotal'] ?? 0} XOF — ${_statusLabelsFr[o['status']] ?? o['status']}', style: TextStyle(color: AppColors.textSecondary)),
                              if (next != null) ...[
                                SizedBox(height: 8),
                                ElevatedButton(onPressed: () => _advance(o['id'], next, o), child: Text('Marquer : ${_statusLabelsFr[next] ?? next}')),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
