import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';

const double _matchRadiusKm = 6;

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = false;
  String? _driverId;
  String _driverStatus = 'pending';
  String _vehicleType = 'moto';
  StreamSubscription? _driverSub;
  StreamSubscription? _posSub;
  StreamSubscription? _geoOrdersSub;
  StreamSubscription? _geoRidesSub;
  List<Map<String, dynamic>> _incomingOrders = [];
  List<Map<String, dynamic>> _incomingRides = [];
  bool _checkedNoApplication = false;
  bool _popupShown = false;
  String? _toggleError;

  @override
  void initState() {
    super.initState();
    _listenDriverDoc();
  }

  void _listenDriverDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) {
        setState(() { _checkedNoApplication = true; _driverId = null; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIdentityPopup());
        return;
      }
      final doc = snap.docs.first;
      setState(() {
        _driverId = doc.id;
        _driverStatus = doc.data()['status'] ?? 'pending';
        _online = doc.data()['isOnline'] ?? false;
        _vehicleType = doc.data()['vehicleType'] ?? 'moto';
        _checkedNoApplication = false;
      });
    });
  }

  void _maybeShowIdentityPopup() {
    if (_popupShown || !mounted) return;
    _popupShown = true;
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, color: AppColors.gold, size: 40),
              const SizedBox(height: 16),
              const Text('Vérification d\'identité requise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Votre compte livreur est créé. Il ne reste qu\'à envoyer vos documents pour l\'activer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/apply-driver');
                },
                child: const Text('Compléter maintenant'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Plus tard', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleOnline(bool value) async {
    if (_driverId == null) return;
    setState(() => _toggleError = null);
    try {
      if (value) {
        final pos = await LocationService().getCurrentPosition();
        await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
          'isOnline': true,
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
        _startGeoMatching(pos.latitude, pos.longitude);
        _posSub?.cancel();
        _posSub = LocationService().watchPosition().listen((p) {
          ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
            'isOnline': true,
            'lat': p.latitude,
            'lng': p.longitude,
          }).catchError((_) {});
          _startGeoMatching(p.latitude, p.longitude);
        }, onError: (e) => debugPrint('[WATCH_POSITION_ERROR] $e'));
      } else {
        await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {'isOnline': false});
        _posSub?.cancel();
        _geoOrdersSub?.cancel();
        _geoRidesSub?.cancel();
        setState(() { _incomingOrders = []; _incomingRides = []; });
      }
      if (mounted) setState(() => _online = value);
    } catch (e) {
      // IMPORTANT: sans ce try/catch, une permission de localisation
      // refusée ou un appel API en échec plantait silencieusement — le
      // livreur restait "hors ligne" sans jamais savoir pourquoi, et sans
      // rien à sélectionner. On affiche maintenant l'erreur clairement.
      debugPrint('[TOGGLE_ONLINE_ERROR] $e');
      if (mounted) {
        final msg = e.toString().toLowerCase().contains('location') || e.toString().toLowerCase().contains('permission')
            ? "Impossible d'accéder à votre position. Vérifiez que la localisation est autorisée pour Livra dans les paramètres du téléphone."
            : 'Erreur : $e';
        setState(() => _toggleError = msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// Relance manuellement la position + le matching géo — utile si le flux
  /// en temps réel s'est arrêté silencieusement (erreur transitoire,
  /// reprise après mise en veille...). Appelé par le "tirer pour actualiser",
  /// disponible en permanence, plus seulement quand la liste n'est pas vide.
  Future<void> _refresh() async {
    if (!_online || _driverId == null) return;
    try {
      final pos = await LocationService().getCurrentPosition();
      _startGeoMatching(pos.latitude, pos.longitude);
      if (mounted) setState(() => _toggleError = null);
    } catch (e) {
      debugPrint('[REFRESH_ERROR] $e');
      if (mounted) setState(() => _toggleError = 'Erreur lors de l\'actualisation : $e');
    }
  }

  /// Requêtes géo (geoflutterfire_plus) sur `orders` ET `rides` en parallèle
  /// — un livreur "coursier" voit les colis, un chauffeur "moto"/"voiture"
  /// voit aussi les courses correspondant à son type de véhicule.
  void _startGeoMatching(double lat, double lng) {
    _geoOrdersSub?.cancel();
    _geoRidesSub?.cancel();
    final center = GeoFirePoint(GeoPoint(lat, lng));

    _geoOrdersSub = GeoCollectionReference<Map<String, dynamic>>(FirebaseFirestore.instance.collection('orders'))
        .subscribeWithin(
          center: center,
          radiusInKm: _matchRadiusKm,
          field: 'matchPosition',
          geopointFrom: (data) => _geopointFrom(data),
          queryBuilder: (query) => query.where('readyForPickup', isEqualTo: true),
        )
        .listen((docs) {
      if (!mounted) return;
      setState(() {
        // Si le client/vendeur a choisi un livreur précis pour cette
        // commande (preferredDriverId), elle ne doit être visible QUE pour
        // lui, pas pour les autres livreurs à proximité.
        _incomingOrders = docs
            .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
            .where((o) => o['preferredDriverId'] == null || o['preferredDriverId'] == _driverId)
            .toList();
      });
    }, onError: (e) {
      // IMPORTANT: sans ce onError, une requête Firestore en échec (index
      // composite manquant, permissions...) restait TOTALEMENT invisible —
      // aucune commande ne s'affichait jamais côté livreur, sans la moindre
      // erreur nulle part. Voir la console/logs si ceci apparaît.
      debugPrint('[GEO_ORDERS_STREAM_ERROR] $e');
      if (mounted) setState(() => _toggleError = 'Erreur de chargement des commandes : $e');
    });

    if (_vehicleType == 'moto' || _vehicleType == 'voiture') {
      _geoRidesSub = GeoCollectionReference<Map<String, dynamic>>(FirebaseFirestore.instance.collection('rides'))
          .subscribeWithin(
            center: center,
            radiusInKm: _matchRadiusKm,
            field: 'matchPosition',
            geopointFrom: (data) => _geopointFrom(data),
            queryBuilder: (query) => query.where('readyForPickup', isEqualTo: true).where('vehicleType', isEqualTo: _vehicleType),
          )
          .listen((docs) {
        if (!mounted) return;
        setState(() {
          _incomingRides = docs
              .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .where((r) => r['preferredDriverId'] == null || r['preferredDriverId'] == _driverId)
              .toList();
        });
      }, onError: (e) {
        debugPrint('[GEO_RIDES_STREAM_ERROR] $e');
        if (mounted) setState(() => _toggleError = 'Erreur de chargement des courses : $e');
      });
    }
  }

  GeoPoint _geopointFrom(Map<String, dynamic> data) {
    final mp = data['matchPosition'] as Map<String, dynamic>?;
    final gp = mp?['geopoint'] as Map<String, dynamic>?;
    if (gp == null) return const GeoPoint(0, 0);
    return GeoPoint((gp['latitude'] as num).toDouble(), (gp['longitude'] as num).toDouble());
  }

  Future<void> _acceptOrder(String orderId) async {
    await ApiClient.instance.patch('/api/orders/$orderId', data: {'status': 'picked_up', 'driverId': _driverId});
    if (mounted) context.push('/driver/navigation/order/$orderId');
  }

  Future<void> _acceptRide(String rideId) async {
    await ApiClient.instance.patch('/api/rides/$rideId', data: {'status': 'accepted', 'driverId': _driverId});
    if (mounted) context.push('/driver/navigation/ride/$rideId');
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _posSub?.cancel();
    _geoOrdersSub?.cancel();
    _geoRidesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_driverId == null && !_checkedNoApplication) return Scaffold(body: SkeletonCardList());

    if (_driverId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace livreur'), actions: [notificationBellAction(context)]),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_outlined, size: 48, color: AppColors.gold),
              const SizedBox(height: 16),
              const Text('Vérification d\'identité requise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Envoyez vos documents pour activer votre compte et accéder à votre tableau de bord.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.push('/apply-driver'), child: const Text('Envoyer mes documents')),
            ],
          ),
        ),
      );
    }

    if (_driverStatus != 'active') {
      return Scaffold(
        appBar: AppBar(title: Text('Espace livreur'), actions: [notificationBellAction(context)]),
        body: EmptyState(
          icon: Icons.hourglass_top_rounded,
          message: _driverStatus == 'pending'
              ? 'Votre candidature est en cours de validation par notre équipe.'
              : _driverStatus == 'rejected'
                  ? 'Votre candidature a été refusée. Contactez le support pour plus de détails.'
                  : 'Votre compte est actuellement suspendu.',
        ),
      );
    }

    final items = <Map<String, dynamic>>[
      ..._incomingOrders.map((o) => {...o, '_kind': 'order'}),
      ..._incomingRides.map((r) => {...r, '_kind': 'ride'}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Espace livreur'),
        actions: [
          IconButton(icon: Icon(Icons.account_balance_wallet_outlined), onPressed: () => context.push('/wallet')),
          IconButton(icon: Icon(Icons.bar_chart_rounded), onPressed: () => context.push('/driver/earnings')),
          IconButton(icon: Icon(Icons.person_outline_rounded), onPressed: () => context.push('/driver/profile')),
          notificationBellAction(context),
        ],
      ),
      body: swipeableTab(
        context: context,
        currentIndex: 0,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: _online ? AppColors.success : AppColors.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _online ? 'En ligne — courses et commandes dans un rayon de ${_matchRadiusKm.toInt()} km' : 'Hors ligne',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                  ),
                  Switch(value: _online, activeColor: AppColors.gold, onChanged: _toggleOnline),
                ],
              ),
            ),
            if (_toggleError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_toggleError!, style: TextStyle(color: AppColors.danger, fontSize: 12.5))),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: AppColors.danger),
                      onPressed: () => setState(() => _toggleError = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              // Le "tirer pour actualiser" est maintenant TOUJOURS disponible
              // (avant: seulement si des éléments étaient déjà affichés — un
              // livreur qui ne voyait rien ne pouvait donc jamais rafraîchir).
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.gold,
                child: !_online
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          EmptyState(icon: Icons.wifi_off_rounded, message: 'Passez en ligne pour recevoir des courses et commandes.'),
                        ],
                      )
                    : items.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              EmptyState(icon: Icons.inbox_outlined, message: 'Rien de disponible à proximité pour le moment. Tirez vers le bas pour actualiser.'),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final isRide = item['_kind'] == 'ride';
                              final title = isRide ? 'Course ${item['vehicleType']}' : 'Commande ${item['type']}';
                              final amount = isRide ? item['price'] : (item['priceBreakdown']?['deliveryFee']);
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: Icon(isRide ? Icons.two_wheeler_rounded : Icons.inventory_2_outlined, color: AppColors.gold),
                                  title: Text(title),
                                  subtitle: Text('${amount ?? '-'} XOF'),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(minimumSize: Size(0, 36), padding: EdgeInsets.symmetric(horizontal: 16)),
                                    onPressed: () => isRide ? _acceptRide(item['id']) : _acceptOrder(item['id']),
                                    child: Text('Accepter'),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
