import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/offline_queue_service.dart';
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
  String? _vendorName;
  String? _vendorPhone;
  String? _vendorUid;
  String? _pickupLabel;
  String? _deliveryLabel;

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
      setState(() {
        _target = snap.data();
        // Adresses lisibles en texte, indispensables pour un coursier — la
        // carte seule ne suffit pas pour savoir "chez qui" aller.
        _pickupLabel = widget.type == 'order'
            ? _target?['pickupAddress']?['label']
            : _target?['pickupLocation']?['label'];
        _deliveryLabel = widget.type == 'order'
            ? _target?['deliveryAddress']?['label']
            : _target?['dropoffLocation']?['label'];
      });
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
        // Contact du vendeur — indispensable pour un livreur qui doit
        // savoir exactement chez qui récupérer une commande nourriture.
        final vendorId = snap.data()?['vendorId'];
        if (widget.type == 'order' && vendorId != null) {
          final vendorSnap = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
          if (vendorSnap.exists && mounted) {
            final ownerId = vendorSnap.data()?['ownerId'];
            setState(() => _vendorName = vendorSnap.data()?['businessName'] ?? 'Vendeur');
            if (ownerId != null) {
              final ownerSnap = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
              if (ownerSnap.exists && mounted) {
                setState(() {
                  _vendorPhone = ownerSnap.data()?['phone'];
                  _vendorUid = ownerId;
                });
              }
            }
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
    final label = widget.type == 'order' ? 'Commande — ${_statusLabelsFr[nextStatus] ?? nextStatus}' : 'Course — ${_statusLabelsFr[nextStatus] ?? nextStatus}';
    // En zone mal couverte, cette mise à jour de statut ne doit jamais se
    // perdre — si le réseau manque, elle est mise en attente et rejouée
    // automatiquement dès que la connexion revient (voir ConnectivityBanner).
    final sentNow = await OfflineQueueService.instance.postOrQueue(
      method: 'patch',
      path: path,
      data: {'status': nextStatus},
      label: label,
    );
    if (!sentNow && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pas de réseau — sera envoyé automatiquement dès que la connexion revient.'),
      ));
    }
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

  static const _statusLabelsFr = {
    'pending': 'En attente',
    'accepted': 'Acceptée',
    'preparing': 'En préparation',
    'picked_up': 'Récupérée',
    'delivering': 'En livraison',
    'arriving': 'Chauffeur en approche',
    'in_progress': 'En cours',
    'delivered': 'Livrée',
    'completed': 'Terminée',
    'cancelled': 'Annulée',
  };

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
                Text('Statut actuel : ${_statusLabelsFr[status] ?? status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                // Adresses lisibles en texte — indispensable pour un
                // coursier: la carte seule ne dit pas "chez qui" aller.
                if (_pickupLabel != null)
                  _AddressRow(icon: Icons.trip_origin_rounded, color: AppColors.success, label: 'Collecte', address: _pickupLabel!),
                if (_deliveryLabel != null) ...[
                  const SizedBox(height: 6),
                  _AddressRow(icon: Icons.location_on_rounded, color: AppColors.danger, label: 'Livraison', address: _deliveryLabel!),
                ],
                const SizedBox(height: 14),
                if (_vendorPhone != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/contact', extra: {
                        'name': _vendorName ?? 'Vendeur',
                        'phoneNumber': _vendorPhone,
                        'role': 'Vendeur Livra',
                        'calleeUid': _vendorUid,
                      }),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: Text('Contacter ${_vendorName ?? "le vendeur"}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
                  PrimaryButton(label: 'Marquer : ${_statusLabelsFr[nextStatus] ?? nextStatus}', onPressed: () => _advanceStatus(nextStatus)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;
  const _AddressRow({required this.icon, required this.color, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              children: [
                TextSpan(text: '$label : ', style: TextStyle(color: AppColors.textSecondary)),
                TextSpan(text: address),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
