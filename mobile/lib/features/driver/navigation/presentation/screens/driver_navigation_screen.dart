import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/maps/maps_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polyline_decoder.dart';
import '../../../../../core/widgets/primary_button.dart';

/// Navigation vers point de collecte puis destination, avec le vrai tracé
/// Directions dessiné sur la carte et une caméra qui suit le livreur
/// ("follow me"), désactivable temporairement si l'utilisateur pan la carte.
class DriverNavigationScreen extends StatefulWidget {
  final String type; // order | ride
  final String id;
  const DriverNavigationScreen({super.key, required this.type, required this.id});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  Map<String, dynamic>? _target;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  final _mapsService = MapsService();
  StreamSubscription? _targetSub;
  StreamSubscription? _positionSub;

  bool _followMe = true;
  bool _boundsFitted = false;

  @override
  void initState() {
    super.initState();
    _listenTarget();
    _startFollowing();
  }

  void _listenTarget() {
    final collection = widget.type == 'order' ? 'orders' : 'rides';
    _targetSub = FirebaseFirestore.instance.collection(collection).doc(widget.id).snapshots().listen((snap) {
      if (!snap.exists) return;
      final wasNull = _target == null;
      setState(() => _target = snap.data());
      if (wasNull) _loadDirections();
    });
  }

  /// Caméra "follow me" : suit la position GPS du livreur en continu.
  /// Se met en pause dès que le livreur pan/zoom manuellement la carte
  /// (voir onCameraMoveStarted), et se réactive via le bouton flottant.
  void _startFollowing() {
    _positionSub = LocationService().watchPosition().listen((pos) {
      if (!_followMe || _mapController == null) return;
      _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
    });
  }

  Future<void> _loadDirections() async {
    if (_target == null) return;
    final originField = widget.type == 'order' ? 'pickupAddress' : 'pickupLocation';
    final destField = widget.type == 'order' ? 'deliveryAddress' : 'dropoffLocation';
    final origin = _target![originField];
    final destination = _target![destField];
    if (origin == null || destination == null) return;

    final o = origin['geopoint'];
    final d = destination['geopoint'];
    final originLatLng = LatLng((o['latitude'] as num).toDouble(), (o['longitude'] as num).toDouble());
    final destLatLng = LatLng((d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble());

    setState(() {
      _markers
        ..clear()
        ..add(Marker(markerId: const MarkerId('origin'), position: originLatLng, infoWindow: const InfoWindow(title: 'Collecte')))
        ..add(Marker(markerId: const MarkerId('destination'), position: destLatLng, infoWindow: const InfoWindow(title: 'Destination')));
    });

    try {
      final res = await _mapsService.directions(
        origin: '${originLatLng.latitude},${originLatLng.longitude}',
        destination: '${destLatLng.latitude},${destLatLng.longitude}',
      );
      final routes = res['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final encoded = routes[0]['overview_polyline']?['points'] as String?;
      if (encoded == null) return;
      final points = decodePolyline(encoded);
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(polylineId: const PolylineId('route'), points: points, color: AppColors.gold, width: 4));
      });
      // Cadrage initial uniquement — une fois le trajet démarré, le "follow me"
      // reprend la main pour suivre le livreur plutôt que le tracé complet.
      if (!_boundsFitted) {
        _fitBounds(points);
        _boundsFitted = true;
      }
    } catch (_) {
      // en cas d'échec Directions (quota, réseau), la carte reste utilisable
      // avec juste les deux markers, sans tracé.
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        60,
      ),
    );
  }

  Future<void> _advanceStatus(String nextStatus) async {
    final path = widget.type == 'order' ? '/api/orders/${widget.id}' : '/api/rides/${widget.id}';
    await ApiClient.instance.patch(path, data: {'status': nextStatus});
  }

  Future<void> _recenter() async {
    setState(() => _followMe = true);
    final pos = await LocationService().getCurrentPosition();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16));
  }

  @override
  void dispose() {
    _targetSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_target == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.gold)));
    final status = _target!['status'];
    final nextStatus = widget.type == 'order'
        ? {'picked_up': 'delivering', 'delivering': 'delivered'}[status]
        : {'accepted': 'arriving', 'arriving': 'in_progress', 'in_progress': 'completed'}[status];

    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FutureBuilder(
                  future: LocationService().getCurrentPosition(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.gold));
                    final pos = snapshot.data!;
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
                      onMapCreated: (c) => _mapController = c,
                      myLocationEnabled: true,
                      polylines: _polylines,
                      markers: _markers,
                      // Le livreur qui pan/zoom manuellement suspend le "follow me" ;
                      // il le réactive via le bouton flottant "recentrer".
                      onCameraMoveStarted: () {
                        if (_followMe) setState(() => _followMe = false);
                      },
                    );
                  },
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter',
                    backgroundColor: _followMe ? AppColors.gold : AppColors.surface,
                    onPressed: _recenter,
                    child: Icon(Icons.navigation_rounded, color: _followMe ? Colors.black : AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statut actuel: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (nextStatus != null)
                  PrimaryButton(label: 'Marquer: $nextStatus', onPressed: () => _advanceStatus(nextStatus)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
