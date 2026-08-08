import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/friendly_error.dart';
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

  int _retryCount = 0;

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.orders, query: {'limit': 30});
      setState(() {
        _orders = res['items'];
        _debugError = null;
        _retryCount = 0;
      });
    } catch (e) {
      // Ne montre plus jamais l'erreur technique brute (permission-denied,
      // codes Firestore...) — l'app se réessaie automatiquement une fois en
      // silence, et n'affiche un message que s'il persiste, jamais le texte
      // technique d'origine.
      debugPrint('[VENDOR_ORDERS_LOAD_ERROR] $e');
      if (_retryCount == 0) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 2), _load);
        return;
      }
      setState(() {
        _orders = [];
        _debugError = 'Impossible de charger vos commandes pour le moment. Tirez vers le bas pour réessayer.';
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
          // BUG CORRIGE: vehicleType: 'coursier' codé en dur excluait tous
          // les livreurs enregistrés en 'moto' ou 'voiture' — alors qu'un
          // taxi-moto ou un chauffeur peut tout aussi bien livrer un
          // colis/une commande. Aucun filtre de véhicule pour une livraison.
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
    // Confirmation visible côté vendeur — sans ça, "ne rien préciser"
    // (diffusion générale) donnait l'impression de ne rien faire, faute
    // de retour visuel immédiat sur cet écran.
    if (mounted && nextStatus == 'picked_up') {
      String message;
      if (offPlatformDriverPhone != null) {
        message = 'Commande marquée livrée hors de Livra.';
      } else if (preferredDriverId != null) {
        message = 'Livreur notifié.';
      } else {
        message = 'Commande proposée à tous les livreurs actifs à proximité.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    _load();
  }

  /// Tant que personne n'a encore collecté la commande (aucun driverId
  /// assigné), le vendeur garde toujours la main pour changer de livreur —
  /// utile si le premier choisi n'a jamais accepté. On renvoie simplement
  /// le statut 'picked_up' avec un nouveau preferredDriverId : le backend
  /// accepte ce renvoi et notifie le nouveau livreur.
  Future<void> _contactDriver(String id) async {
    try {
      final detail = await ApiClient.instance.get('/api/orders/$id');
      final driverInfo = detail['driverInfo'] as Map<String, dynamic>?;
      if (driverInfo == null || driverInfo['phone'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Numéro du livreur non disponible.')));
        }
        return;
      }
      if (mounted) {
        context.push('/contact', extra: {
          'name': driverInfo['name'] ?? 'Livreur',
          'phoneNumber': driverInfo['phone'],
          'role': 'Livreur Livra',
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _confirmDelivery(String id) async {
    try {
      await ApiClient.instance.patch('/api/orders/$id', data: {'vendorConfirmDelivery': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livraison confirmée.')));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _changeDriver(String id, Map order) async {
    final geopoint = order['matchPosition']?['geopoint'];
    if (geopoint == null) return;
    final result = await pickDriver(
      context,
      lat: (geopoint['latitude'] as num).toDouble(),
      lng: (geopoint['longitude'] as num).toDouble(),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_debugError!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
                        ],
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/order-detail/order/${o['id']}'),
                          child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Commande ${o['id'].toString().substring(0, 6)}', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${o['priceBreakdown']?['subtotal'] ?? 0} XOF — ${o['deliveredOffPlatform'] == true ? 'Livré hors de Livra' : (_statusLabelsFr[o['status']] ?? o['status'])}', style: TextStyle(color: AppColors.textSecondary)),
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
                              // Demande explicite: une fois un livreur assigné
                              // (collecté), le vendeur doit pouvoir le
                              // contacter directement pour aller plus vite.
                              if (o['driverId'] != null) ...[
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _contactDriver(o['id']),
                                  icon: Icon(Icons.call_outlined, size: 16),
                                  label: Text('Contacter le livreur'),
                                ),
                              ],
                              // Le livreur a déclaré la commande livrée — le
                              // vendeur doit vérifier auprès du client puis
                              // confirmer lui-même (double contrôle).
                              if (o['status'] == 'delivered' && o['vendorConfirmedDelivery'] != true) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.help_outline_rounded, size: 16, color: AppColors.warning),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Le livreur a déclaré cette commande livrée. Vérifiez auprès de votre client puis confirmez.',
                                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _confirmDelivery(o['id']),
                                  icon: Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: Text('Confirmer la livraison'),
                                ),
                              ],
                              if (o['status'] == 'delivered' && o['vendorConfirmedDelivery'] == true) ...[
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                                    const SizedBox(width: 6),
                                    Text('Livraison confirmée', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
