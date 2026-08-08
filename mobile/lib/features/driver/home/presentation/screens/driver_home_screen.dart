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

// Statuts "en cours" — tant qu'une commande/course de ce livreur est dans
// l'un de ces statuts, elle reste accessible en un tap depuis l'accueil
// (voir bandeau "Livraison en cours") : un livreur qui quitte l'écran de
// navigation par erreur doit toujours pouvoir y retourner.
const _activeOrderStatuses = ['picked_up', 'delivering'];
const _activeRideStatuses = ['accepted', 'arriving', 'in_progress'];

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
  StreamSubscription? _reservedOrdersSub;
  StreamSubscription? _reservedRidesSub;
  StreamSubscription? _activeOrdersSub;
  StreamSubscription? _activeRidesSub;
  List<Map<String, dynamic>> _incomingOrders = [];
  List<Map<String, dynamic>> _incomingRides = [];
  // Commandes/courses où LE CLIENT (ou vendeur) m'a réservé précisément,
  // AVANT même que le plat soit prêt / que la course soit "readyForPickup".
  List<Map<String, dynamic>> _reservedOrders = [];
  List<Map<String, dynamic>> _reservedRides = [];
  // Livraisons/courses DÉJÀ acceptées par moi et en cours — permet de
  // revenir sur l'écran de navigation même après être reparti par erreur
  // sur l'accueil, pour ce livreur ET tout autre type (coursier, chauffeur,
  // taxi-moto...), même principe pour tous.
  Map<String, dynamic>? _activeOrder;
  Map<String, dynamic>? _activeRide;
  bool _checkedNoApplication = false;
  bool _popupShown = false;
  int _geoRetryCount = 0;

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
      _listenReservedForMe(doc.id);
      _listenActiveForMe(doc.id);
    });
  }

  /// Écoute directe (pas géo, pas de dépendance à "en ligne" ni à
  /// readyForPickup) sur tout ce qui m'a été réservé précisément — un
  /// client ou un vendeur qui m'a choisi doit toujours m'apparaître ici,
  /// même avant que la commande soit prête côté vendeur.
  void _listenReservedForMe(String driverId) {
    _reservedOrdersSub?.cancel();
    _reservedRidesSub?.cancel();
    _reservedOrdersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('preferredDriverId', isEqualTo: driverId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _reservedOrders = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((o) => o['driverId'] == null) // pas déjà réclamée
            .toList();
      });
    }, onError: (e) => debugPrint('[RESERVED_ORDERS_ERROR] $e'));

    _reservedRidesSub = FirebaseFirestore.instance
        .collection('rides')
        .where('preferredDriverId', isEqualTo: driverId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _reservedRides = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((r) => r['driverId'] == null)
            .toList();
      });
    }, onError: (e) => debugPrint('[RESERVED_RIDES_ERROR] $e'));
  }

  /// Livraison/course DÉJÀ acceptée par moi et toujours en cours — permet
  /// de revenir dessus (bandeau "Continuer" en haut de l'accueil) même
  /// après être reparti par erreur, sans perdre le fil. Ne dépend ni du
  /// statut en ligne ni de readyForPickup — l'app se souvient toujours de
  /// ce qui est en cours, jusqu'à ce que ce soit terminé.
  void _listenActiveForMe(String driverId) {
    _activeOrdersSub?.cancel();
    _activeRidesSub?.cancel();
    _activeOrdersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final active = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((o) => _activeOrderStatuses.contains(o['status']))
          .toList();
      setState(() => _activeOrder = active.isNotEmpty ? active.first : null);
    }, onError: (e) => debugPrint('[ACTIVE_ORDERS_ERROR] $e'));

    _activeRidesSub = FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final active = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((r) => _activeRideStatuses.contains(r['status']))
          .toList();
      setState(() => _activeRide = active.isNotEmpty ? active.first : null);
    }, onError: (e) => debugPrint('[ACTIVE_RIDES_ERROR] $e'));
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
        _posSub = LocationService().watchPosition().listen((p) async {
          try {
            await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
              'isOnline': true,
              'lat': p.latitude,
              'lng': p.longitude,
            });
          } catch (_) {}
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
      // Seule erreur encore montrée à l'utilisateur: la localisation, car
      // c'est la SEULE chose qu'il peut lui-même corriger (autoriser la
      // position dans les paramètres du téléphone). Tout le reste
      // (synchronisation serveur, permissions Firestore) se répare tout
      // seul en silence — voir _startGeoMatching ci-dessous — un livreur
      // ne doit jamais voir de message technique sur son tableau de bord.
      debugPrint('[TOGGLE_ONLINE_ERROR] $e');
      final isLocation = e.toString().toLowerCase().contains('location') || e.toString().toLowerCase().contains('permission');
      if (mounted && isLocation) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Impossible d'accéder à votre position. Vérifiez que la localisation est autorisée pour Livra dans les paramètres du téléphone."),
        ));
      }
    }
  }

  /// Relance manuellement la position + le matching géo — utile si le flux
  /// en temps réel s'est arrêté (mise en veille prolongée...). Disponible
  /// en permanence via le "tirer pour actualiser".
  Future<void> _refresh() async {
    if (!_online || _driverId == null) return;
    try {
      final pos = await LocationService().getCurrentPosition();
      await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
        'isOnline': true,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
      _geoRetryCount = 0;
      _startGeoMatching(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[REFRESH_ERROR] $e');
    }
  }

  /// Requêtes géo (geoflutterfire_plus) sur `orders` ET `rides` en parallèle
  /// — un livreur "coursier" voit les colis, un chauffeur "moto"/"voiture"
  /// voit aussi les courses correspondant à son type de véhicule.
  ///
  /// IMPORTANT: plus AUCUNE erreur n'est jamais affichée à l'écran ici —
  /// demande explicite ("aucune erreur ne sera dans l'application"). En
  /// cas d'échec (ex: synchronisation serveur pas encore terminée), l'app
  /// se répare TOUTE SEULE en silence: elle réessaie de se resynchroniser
  /// puis relance la requête, jusqu'à 3 fois avec un court délai, sans
  /// jamais rien montrer à l'utilisateur. Seuls les logs de debug (invisibles
  /// en usage normal) tracent ce qui se passe, pour le support technique.
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
      _geoRetryCount = 0;
      setState(() {
        _incomingOrders = docs
            .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
            .where((o) => o['preferredDriverId'] == null || o['preferredDriverId'] == _driverId)
            .toList();
      });
    }, onError: (e) {
      debugPrint('[GEO_ORDERS_STREAM_ERROR] $e');
      _selfHealGeoMatching(lat, lng);
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
        _geoRetryCount = 0;
        setState(() {
          _incomingRides = docs
              .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .where((r) => r['preferredDriverId'] == null || r['preferredDriverId'] == _driverId)
              .toList();
        });
      }, onError: (e) {
        debugPrint('[GEO_RIDES_STREAM_ERROR] $e');
        _selfHealGeoMatching(lat, lng);
      });
    }
  }

  /// Auto-réparation silencieuse: resynchronise activeDriverId côté
  /// serveur puis relance la requête géo, jusqu'à 3 tentatives avec un
  /// court délai croissant. Ne montre jamais rien à l'utilisateur.
  void _selfHealGeoMatching(double lat, double lng) {
    if (!mounted || !_online || _driverId == null) return;
    if (_geoRetryCount >= 3) {
      debugPrint('[GEO_SELF_HEAL] abandon après 3 tentatives');
      return;
    }
    _geoRetryCount++;
    Future.delayed(Duration(seconds: _geoRetryCount * 2), () async {
      if (!mounted || !_online) return;
      try {
        await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
          'isOnline': true,
          'lat': lat,
          'lng': lng,
        });
      } catch (_) {}
      if (mounted && _online) _startGeoMatching(lat, lng);
    });
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

  /// Demande explicite: le livreur doit d'abord LIRE les détails complets
  /// de la commande/course avant de pouvoir l'accepter — jamais un
  /// engagement immédiat en un tap, pour éviter tout malentendu. Il peut
  /// ensuite valider (accepter) ou refuser et passer sans conséquence.
  Future<void> _showJobDetailSheet(Map<String, dynamic> item, bool isRide) async {
    final id = item['id'];
    Map<String, dynamic>? detail;
    try {
      detail = await ApiClient.instance.get(isRide ? '/api/rides/$id' : '/api/orders/$id');
    } catch (_) {
      detail = item; // repli sur les données déjà en main si l'appel échoue
    }
    if (!mounted) return;
    final vendorInfo = detail['vendorInfo'] as Map<String, dynamic>?;
    final pickupLabel = isRide ? detail['pickupLocation']?['label'] : detail['pickupAddress']?['label'];
    final deliveryLabel = isRide ? detail['dropoffLocation']?['label'] : detail['deliveryAddress']?['label'];
    final amount = isRide ? detail['price'] : detail['priceBreakdown']?['deliveryFee'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isRide ? 'Détail de la course' : 'Détail de la livraison', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('${amount ?? '-'} XOF', style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              if (vendorInfo != null) ...[
                Text('Vendeur : ${vendorInfo['businessName'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
              ],
              if (pickupLabel != null) _detailLine(Icons.trip_origin_rounded, AppColors.success, 'Collecte', pickupLabel),
              if (deliveryLabel != null) _detailLine(Icons.location_on_rounded, AppColors.danger, 'Livraison', deliveryLabel),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        isRide ? _acceptRide(id) : _acceptOrder(id);
                      },
                      child: const Text('Valider et livrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                children: [
                  TextSpan(text: '$label : ', style: TextStyle(color: AppColors.textSecondary)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _posSub?.cancel();
    _geoOrdersSub?.cancel();
    _geoRidesSub?.cancel();
    _reservedOrdersSub?.cancel();
    _reservedRidesSub?.cancel();
    _activeOrdersSub?.cancel();
    _activeRidesSub?.cancel();
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

    // Fusionne diffusion générale (readyForPickup) + réservations
    // personnelles (préparation en cours côté vendeur) — sans doublons.
    final geoIds = {..._incomingOrders.map((o) => o['id']), ..._incomingRides.map((r) => r['id'])};
    final items = <Map<String, dynamic>>[
      ..._incomingOrders.map((o) => {...o, '_kind': 'order'}),
      ..._incomingRides.map((r) => {...r, '_kind': 'ride'}),
      ..._reservedOrders.where((o) => !geoIds.contains(o['id'])).map((o) => {...o, '_kind': 'order', '_reserved': true}),
      ..._reservedRides.where((r) => !geoIds.contains(r['id'])).map((r) => {...r, '_kind': 'ride', '_reserved': true}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Espace livreur'),
        actions: [
          IconButton(icon: Icon(Icons.history_rounded), tooltip: 'Historique', onPressed: () => context.push('/driver/history')),
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
            // Bandeau "Livraison en cours" — permet de revenir sur l'écran
            // de navigation même après en être reparti par erreur (ça
            // arrive). Toujours visible, indépendamment du statut en ligne,
            // tant qu'une commande/course confiée à ce livreur n'est pas
            // terminée.
            if (_activeOrder != null || _activeRide != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (_activeOrder != null)
                      _ActiveJobBanner(
                        icon: Icons.inventory_2_outlined,
                        label: 'Livraison en cours — ${_activeOrder!['type'] ?? ''}',
                        onTap: () => context.push('/driver/navigation/order/${_activeOrder!['id']}'),
                      ),
                    if (_activeRide != null)
                      _ActiveJobBanner(
                        icon: Icons.two_wheeler_rounded,
                        label: 'Course en cours — ${_activeRide!['vehicleType'] ?? ''}',
                        onTap: () => context.push('/driver/navigation/ride/${_activeRide!['id']}'),
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
                // IMPORTANT: les réservations personnelles (_reservedOrders/
                // _reservedRides) restent visibles MÊME hors ligne — un
                // client/vendeur qui a choisi ce livreur doit toujours le
                // voir sur son tableau de bord, peu importe son statut "en
                // ligne" (c'est justement ce qui manquait). Seule la
                // diffusion générale (items géo) est coupée hors ligne.
                child: (!_online && items.isEmpty)
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
                              final reserved = item['_reserved'] == true;
                              final title = isRide ? 'Course ${item['vehicleType']}' : 'Commande ${item['type']}';
                              final amount = isRide ? item['price'] : (item['priceBreakdown']?['deliveryFee']);
                              final canAct = !(reserved && !isRide && item['readyForPickup'] != true);
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: canAct ? () => _showJobDetailSheet(item, isRide) : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(isRide ? Icons.two_wheeler_rounded : Icons.inventory_2_outlined, color: AppColors.gold),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 3),
                                              Text(
                                                reserved
                                                    ? '${amount ?? '-'} XOF — Réservée pour vous, en attente de préparation'
                                                    : '${amount ?? '-'} XOF',
                                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                                softWrap: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Une commande nourriture réservée mais
                                        // pas encore marquée "prête" par le
                                        // vendeur ne peut pas encore être
                                        // acceptée — juste visible, pour que le
                                        // livreur sache qu'il est attendu.
                                        canAct
                                            ? Icon(Icons.chevron_right_rounded, color: AppColors.gold)
                                            : Icon(Icons.hourglass_top_rounded, color: AppColors.textSecondary, size: 20),
                                      ],
                                    ),
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

/// Bandeau "en cours" — permet de revenir sur une livraison/course déjà
/// acceptée sans perdre le fil si le livreur est reparti par erreur sur
/// l'accueil.
class _ActiveJobBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActiveJobBanner({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right_rounded, color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
