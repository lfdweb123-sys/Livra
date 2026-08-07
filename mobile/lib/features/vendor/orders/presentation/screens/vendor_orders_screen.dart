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
  String? _debugError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.orders, query: {'limit': 30});
      setState(() {
        _orders = res['items'];
        _debugError = null;
      });
    } catch (e) {
      // IMPORTANT: avant ce correctif, toute erreur ici (réseau, 500,
      // permissions) était totalement invisible — la page restait juste
      // vide, sans le moindre indice. On affiche maintenant l'erreur brute
      // directement dans l'app pour diagnostiquer sans devoir aller
      // chercher dans les logs Vercel.
      debugPrint('[VENDOR_ORDERS_LOAD_ERROR] $e');
      setState(() {
        _orders = [];
        _debugError = e.toString();
      });
    }
  }

  Future<void> _advance(String id, String nextStatus, Map order) async {
    String? preferredDriverId;
    String? offPlatformDriverPhone;
    if (nextStatus == 'picked_up') {
      // Le restaurant peut choisir un livreur actif précis pour venir
      // récupérer la commande, un livreur hors application (numéro
      // transmis à l'admin), ou ne rien préciser (livreur proposé à tous
      // les livreurs à proximité comme avant).
      final geopoint = order['matchPosition']?['geopoint'];
      if (geopoint != null) {
        final result = await pickDriver(
          context,
          lat: (geopoint['latitude'] as num).toDouble(),
          lng: (geopoint['longitude'] as num).toDouble(),
          vehicleType: 'coursier',
          title: 'Choisir un livreur',
        );
        preferredDriverId = result.driverId;
        offPlatformDriverPhone = result.offPlatformPhone;
      }
    }
    await ApiClient.instance.patch('/api/orders/$id', data: {
      'status': nextStatus,
      if (preferredDriverId != null) 'preferredDriverId': preferredDriverId,
      if (offPlatformDriverPhone != null) 'offPlatformDriverPhone': offPlatformDriverPhone,
    });
    _load();
  }

  /// Tant que personne n'a encore collecté la commande (aucun driverId
  /// assigné), le vendeur garde toujours la main pour changer de livreur —
  /// utile si le premier choisi n'a jamais accepté. On renvoie simplement
  /// le statut 'picked_up' avec un nouveau preferredDriverId : le backend
  /// accepte ce renvoi et notifie le nouveau livreur.
  Future<void> _changeDriver(String id, Map order) async {
    final geopoint = order['matchPosition']?['geopoint'];
    if (geopoint == null) return;
    final result = await pickDriver(
      context,
      lat: (geopoint['latitude'] as num).toDouble(),
      lng: (geopoint['longitude'] as num).toDouble(),
      vehicleType: 'coursier',
      title: 'Changer de livreur',
    );
    try {
      await ApiClient.instance.patch('/api/orders/$id', data: {
        'status': 'picked_up',
        if (result.driverId != null) 'preferredDriverId': result.driverId,
        if (result.offPlatformPhone != null) 'offPlatformDriverPhone': result.offPlatformPhone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.driverId != null
              ? 'Nouveau livreur notifié.'
              : result.offPlatformPhone != null
                  ? 'Livreur hors application enregistré.'
                  : 'Commande de nouveau proposée à tous les livreurs à proximité.'),
        ));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
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
            : Column(
                children: [
                  if (_debugError != null)
                    Container(
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Erreur: $_debugError',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  Expanded(
                    child: _orders!.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 80),
                            EmptyState(icon: Icons.receipt_long_outlined, message: 'Aucune commande pour le moment.'),
                          ])
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
                              // Tant qu'aucun livreur n'a réellement collecté
                              // (driverId toujours vide), le vendeur garde
                              // toujours accès pour changer de livreur —
                              // notamment si le premier choisi n'a jamais
                              // accepté la commande.
                              if (o['status'] == 'picked_up' && o['driverId'] == null) ...[
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _changeDriver(o['id'], o),
                                  icon: Icon(Icons.sync_alt_rounded, size: 16),
                                  label: Text('Changer de livreur'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  ),
                ],
              ),
      ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
