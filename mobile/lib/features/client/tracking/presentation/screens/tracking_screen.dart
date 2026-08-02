import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/review_sheet.dart';

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
  String? _driverName;
  String? _driverPhone;
  String? _driverUid;
  String? _driverPhotoUrl;
  StreamSubscription? _sub;
  StreamSubscription? _driverSub;

  @override
  void initState() {
    super.initState();
    final collection = widget.type == 'order' ? 'orders' : 'rides';
    _sub = _db.collection(collection).doc(widget.id).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final newStatus = data['status'] ?? 'pending';
      final justFinished = (widget.type == 'order' && newStatus == 'delivered' && _status != 'delivered') ||
          (widget.type == 'ride' && newStatus == 'completed' && _status != 'completed');
      setState(() => _status = newStatus);
      final driverId = data['driverId'];
      if (driverId != null) _listenDriver(driverId);
      if (justFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptReview());
      }
    });
  }

  Future<void> _promptReview() async {
    if (!mounted) return;
    await showReviewSheet(
      context,
      orderId: widget.type == 'order' ? widget.id : null,
      rideId: widget.type == 'ride' ? widget.id : null,
      targetLabel: widget.type == 'order' ? (_driverName ?? 'ce service') : (_driverName ?? 'votre chauffeur'),
    );
  }

  void _listenDriver(String driverId) {
    _driverSub?.cancel();
    _driverSub = _db.collection('drivers').doc(driverId).snapshots().listen((snap) async {
      if (!snap.exists) return;
      final driverData = snap.data()!;
      final position = driverData['position']?['geopoint'];
      if (position != null) {
        final newPos = ll.LatLng((position['latitude'] as num).toDouble(), (position['longitude'] as num).toDouble());
        setState(() {
          _previousPosition = _driverPosition ?? newPos;
          _driverPosition = newPos;
        });
      }
      if (_driverPhotoUrl != driverData['photoUrl'] && mounted) {
        setState(() => _driverPhotoUrl = driverData['photoUrl']);
      }
      if (_driverName == null && driverData['ownerId'] != null) {
        final userSnap = await _db.collection('users').doc(driverData['ownerId']).get();
        if (userSnap.exists && mounted) {
          setState(() {
            _driverName = userSnap.data()?['name'] ?? 'Votre livreur';
            _driverPhone = userSnap.data()?['phone'];
            _driverUid = driverData['ownerId'];
          });
        }
      }
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

  String _homeRoute() => '/client/home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi en temps réel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(_homeRoute()),
        ),
      ),
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
                if (_driverPhone != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceElevated,
                        backgroundImage: _driverPhotoUrl != null ? NetworkImage(_driverPhotoUrl!) : null,
                        child: _driverPhotoUrl == null ? Icon(Icons.person_outline_rounded, color: AppColors.textSecondary) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_driverName ?? 'Votre livreur', style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/contact', extra: {
                        'name': _driverName ?? 'Votre livreur',
                        'phoneNumber': _driverPhone,
                        'role': 'Livreur/chauffeur Livra',
                        'calleeUid': _driverUid,
                        'photoUrl': _driverPhotoUrl,
                      }),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text('Contacter ${_driverName ?? "le livreur"}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
