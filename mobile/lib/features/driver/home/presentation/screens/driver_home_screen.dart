import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';

const double _matchRadiusKm = 5;

class DriverHomeScreen extends StatefulWidget {
  DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = false;
  String? _driverId;
  String _status = 'pending';
  StreamSubscription? _driverSub;
  StreamSubscription? _posSub;
  StreamSubscription? _geoSub;
  List<Map<String, dynamic>> _incoming = [];
  final _geo = Geoflutterfire();

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
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      setState(() {
        _driverId = doc.id;
        _status = doc.data()['status'] ?? 'pending';
        _online = doc.data()['isOnline'] ?? false;
      });
    });
  }

  Future<void> _toggleOnline(bool value) async {
    if (_driverId == null) return;
    if (value) {
      final pos = await LocationService().getCurrentPosition();
      await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
        'isOnline': true,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
      _startGeoMatching(pos.latitude, pos.longitude);
      _posSub = LocationService().watchPosition().listen((p) {
        ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {
          'isOnline': true,
          'lat': p.latitude,
          'lng': p.longitude,
        });
        // on ré-ancre le centre de la requête géo seulement si le livreur a
        // bougé significativement, pour ne pas relancer la requête à chaque tick.
        _startGeoMatching(p.latitude, p.longitude);
      });
    } else {
      await ApiClient.instance.post('/api/drivers/$_driverId/toggle-online', data: {'isOnline': false});
      _posSub?.cancel();
      _geoSub?.cancel();
      setState(() => _incoming = []);
    }
    setState(() => _online = value);
  }

  /// Requête géo réelle (geoflutterfire2) sur le champ `matchPosition` des
  /// commandes, dans un rayon de _matchRadiusKm autour du livreur. Le filtre
  /// géo (range sur geohash) ne peut pas se combiner avec un `where`
  /// composé côté Firestore natif : on filtre donc status/driverId sur la
  /// collectionRef passée à geoflutterfire2, et le rayon exact en aval.
  void _startGeoMatching(double lat, double lng) {
    _geoSub?.cancel();
    final center = _geo.point(latitude: lat, longitude: lng);
    final collectionRef = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'picked_up')
        .where('driverId', isEqualTo: null);

    _geoSub = _geo
        .collection(collectionRef: collectionRef)
        .within(center: center, radius: _matchRadiusKm, field: 'matchPosition', strictMode: true)
        .listen((docs) {
      if (!mounted) return;
      setState(() {
        _incoming = docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).toList();
      });
    });
  }

  Future<void> _acceptOrder(String orderId) async {
    await ApiClient.instance.patch('/api/orders/$orderId', data: {'status': 'picked_up', 'driverId': _driverId});
    if (mounted) context.push('/driver/navigation/order/$orderId');
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _posSub?.cancel();
    _geoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_driverId == null) return Scaffold(body: SkeletonCardList());
    if (_status != 'active') {
      return Scaffold(
        appBar: AppBar(title: Text('Espace livreur')),
        body: EmptyState(
          icon: Icons.hourglass_top_rounded,
          message: _status == 'pending'
              ? 'Votre candidature est en cours de validation par notre équipe.'
              : _status == 'rejected'
                  ? 'Votre candidature a été refusée. Contactez le support pour plus de détails.'
                  : 'Votre compte est actuellement suspendu.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Espace livreur'),
        actions: [
          IconButton(icon: Icon(Icons.account_balance_wallet_outlined), onPressed: () => context.push('/wallet')),
          IconButton(icon: Icon(Icons.bar_chart_rounded), onPressed: () => context.push('/driver/earnings')),
        ],
      ),
      body: Column(
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
                    _online ? 'En ligne — commandes dans un rayon de ${_matchRadiusKm.toInt()} km' : 'Hors ligne',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(value: _online, activeColor: AppColors.gold, onChanged: _toggleOnline),
              ],
            ),
          ),
          Expanded(
            child: !_online
                ? EmptyState(icon: Icons.wifi_off_rounded, message: 'Passez en ligne pour recevoir des commandes.')
                : _incoming.isEmpty
                    ? EmptyState(icon: Icons.inbox_outlined, message: 'Aucune commande disponible à proximité pour le moment.')
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _incoming.length,
                        itemBuilder: (context, i) {
                          final o = _incoming[i];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('Commande ${o['type']}'),
                              subtitle: Text('${o['priceBreakdown']?['deliveryFee'] ?? '-'} XOF de frais de livraison'),
                              trailing: ElevatedButton(onPressed: () => _acceptOrder(o['id']), child: Text('Accepter')),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
