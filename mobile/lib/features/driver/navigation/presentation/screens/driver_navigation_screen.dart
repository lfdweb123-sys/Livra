import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/maps/maps_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';

/// Navigation vers point de collecte puis destination, avec le vrai tracé
/// OSRM dessiné sur la carte (gratuit, sans clé API) et une caméra qui suit
/// le livreur ("follow me"), désactivable si l'utilisateur pan la carte.
class DriverNavigationScreen extends StatefulWidget {
  final String type; // order | ride
  final String id;
  const DriverNavigationScreen({super.key, required this.type, required this.id});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  Map<String, dynamic>? _target;
  List<ll.LatLng> _routePoints = [];
  ll.LatLng? _origin;
  ll.LatLng? _destination;
  final _mapController = MapController();
  final _mapsService = MapsService();
  StreamSubscription? _targetSub;
  StreamSubscription? _positionSub;

  bool _followMe = true;
  bool _fitted = false;
  String? _clientName;
  String? _clientPhone;
  String? _clientUid;

  @override
  void initState() {
    super.initState();
    _listenTarget();
    _startFollowing();
  }

  void _listenTarget() {
    final collection = widget.type == 'order' ? 'orders' : 'rides';
    _targetSub = FirebaseFirestore.instance.collection(collection).doc(widget.id).snapshots().listen((snap) async {
      if (!snap.exists) return;
      final wasNull = _target == null;
      setState(() => _target = snap.data());
      if (wasNull) {
        _loadDirections();
        final clientId = snap.data()?['clientId'];
        if (clientId != null) {
          final userSnap = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
          if (userSnap.exists && mounted) {
            setState(() {
              _clientName = userSnap.data()?['name'] ?? 'Client';
              _clientPhone = userSnap.data()?['phone'];
              _clientUid = clientId;
            });
          }
        }
      }
    });
  }

  void _startFollowing() {
    _positionSub = LocationService().watchPosition().listen((pos) {
      if (!_followMe) return;
      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
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
    final originLatLng = ll.LatLng((o['latitude'] as num).toDouble(), (o['longitude'] as num).toDouble());
    final destLatLng = ll.LatLng((d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble());

    setState(() {
      _origin = originLatLng;
      _destination = destLatLng;
    });

    try {
      final res = await _mapsService.directions(
        origin: '${originLatLng.latitude},${originLatLng.longitude}',
        destination: '${destLatLng.latitude},${destLatLng.longitude}',
      );
      final coords = (res['coordinates'] as List?)
          ?.map((c) => ll.LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();
      if (coords == null || coords.isEmpty) return;
      setState(() => _routePoints = coords);
      if (!_fitted) {
        _mapController.fitCamera(CameraFit.coordinates(coordinates: coords, padding: const EdgeInsets.all(60)));
        _fitted = true;
      }
    } catch (_) {
      // itinéraire indisponible (OSRM en panne, réseau...) — la carte reste
      // utilisable avec juste les markers, sans tracé.
    }
  }

  Future<void> _advanceStatus(String nextStatus) async {
    final path = widget.type == 'order' ? '/api/orders/${widget.id}' : '/api/rides/${widget.id}';
    await ApiClient.instance.patch(path, data: {'status': nextStatus});
  }

  Future<void> _recenter() async {
    setState(() => _followMe = true);
    final pos = await LocationService().getCurrentPosition();
    _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 16);
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
                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: ll.LatLng(pos.latitude, pos.longitude),
                        initialZoom: 15,
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture && _followMe) setState(() => _followMe = false);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.lfd.livra',
                        ),
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(points: _routePoints, strokeWidth: 4, color: AppColors.gold),
                          ]),
                        MarkerLayer(markers: [
                          if (_origin != null)
                            Marker(point: _origin!, width: 36, height: 36, child: Icon(Icons.trip_origin_rounded, color: AppColors.success)),
                          if (_destination != null)
                            Marker(point: _destination!, width: 36, height: 36, child: Icon(Icons.location_on_rounded, color: AppColors.danger)),
                        ]),
                      ],
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
                if (_clientPhone != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/contact', extra: {
                        'name': _clientName ?? 'Client',
                        'phoneNumber': _clientPhone,
                        'role': 'Client Livra',
                        'calleeUid': _clientUid,
                      }),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text('Contacter ${_clientName ?? "le client"}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
