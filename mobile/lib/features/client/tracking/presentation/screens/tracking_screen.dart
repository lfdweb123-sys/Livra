import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../core/theme/app_colors.dart';

/// Tracking live : le marker interpole entre l'ancienne et la nouvelle
/// position du chauffeur au lieu de sauter, via un TweenAnimationBuilder
/// piloté par le stream Firestore drivers/{id}. Carte OpenStreetMap
/// (gratuite, sans clé API).
class TrackingScreen extends StatefulWidget {
  final String type; // order | ride
  final String id;
  const TrackingScreen({super.key, required this.type, required this.id});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _db = FirebaseFirestore.instance;
  ll.LatLng? _driverPosition;
  ll.LatLng? _previousPosition;
  String _status = 'pending';
  StreamSubscription? _sub;
  StreamSubscription? _driverSub;

  @override
  void initState() {
    super.initState();
    final collection = widget.type == 'order' ? 'orders' : 'rides';
    _sub = _db.collection(collection).doc(widget.id).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      setState(() => _status = data['status'] ?? 'pending');
      final driverId = data['driverId'];
      if (driverId != null) _listenDriver(driverId);
    });
  }

  void _listenDriver(String driverId) {
    _driverSub?.cancel();
    _driverSub = _db.collection('drivers').doc(driverId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final position = snap.data()?['position']?['geopoint'];
      if (position == null) return;
      final newPos = ll.LatLng((position['latitude'] as num).toDouble(), (position['longitude'] as num).toDouble());
      setState(() {
        _previousPosition = _driverPosition ?? newPos;
        _driverPosition = newPos;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  static const _statusLabels = {
    'pending': 'En attente',
    'accepted': 'Acceptée',
    'preparing': 'En préparation',
    'picked_up': 'Récupérée',
    'delivering': 'En livraison',
    'arriving': "Chauffeur en approche",
    'in_progress': 'En cours',
    'delivered': 'Livrée',
    'completed': 'Terminée',
    'cancelled': 'Annulée',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi en temps réel')),
      body: Column(
        children: [
          Expanded(
            child: _driverPosition == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.gold),
                        SizedBox(height: 12),
                        Text('En attente d\'assignation…', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, t, child) {
                      final lat = _previousPosition!.latitude + (_driverPosition!.latitude - _previousPosition!.latitude) * t;
                      final lng = _previousPosition!.longitude + (_driverPosition!.longitude - _previousPosition!.longitude) * t;
                      final animatedPos = ll.LatLng(lat, lng);
                      return FlutterMap(
                        options: MapOptions(initialCenter: animatedPos, initialZoom: 15),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.lfd.livra',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: animatedPos,
                              width: 44,
                              height: 44,
                              child: Icon(Icons.two_wheeler_rounded, color: AppColors.gold, size: 34),
                            ),
                          ]),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabels[_status] ?? _status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Nous vous notifions à chaque étape.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
