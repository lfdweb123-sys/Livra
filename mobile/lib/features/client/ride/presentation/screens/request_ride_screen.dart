import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/payment/payment_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';

class RequestRideScreen extends StatefulWidget {
  final String? initialVehicleType;
  RequestRideScreen({super.key, this.initialVehicleType});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickup;
  LatLng? _dropoff;
  late String _vehicleType;
  bool _requesting = false;
  String? _rideId;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.initialVehicleType ?? 'moto';
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      setState(() => _pickup = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _requestRide() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _requesting = true);
    try {
      final res = await ApiClient.instance.post(ApiConstants.rides, data: {
        'pickupLocation': {
          'geopoint': {'latitude': _pickup!.latitude, 'longitude': _pickup!.longitude}
        },
        'dropoffLocation': {
          'geopoint': {'latitude': _dropoff!.latitude, 'longitude': _dropoff!.longitude}
        },
        'vehicleType': _vehicleType,
      });
      _rideId = res['id'];
      if (mounted) {
        await showAppBottomSheet(
          context,
          title: 'Course estimée',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prix: ${res['price']} XOF'),
              Text('Distance: ${res['distanceKm']} km'),
              Text('ETA: ${res['etaMinutes']} min'),
              SizedBox(height: 16),
              PrimaryButton(
                label: 'Choisir le paiement',
                onPressed: () {
                  Navigator.pop(context);
                  _choosePayment();
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _choosePayment() async {
    if (_rideId == null) return;
    await showAppBottomSheet(
      context,
      title: 'Moyen de paiement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: Text('Mobile Money (FeexPay Bénin)'),
            onTap: _payFeexpay,
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: Text('Verzapay (carte / Mobile Money)'),
            onTap: _payVerzapay,
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
            title: Text('Portefeuille Livra'),
            onTap: () {
              Navigator.pop(context);
              context.go('/client/tracking/ride/$_rideId');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _payFeexpay() async {
    Navigator.pop(context);
    final phoneCtrl = TextEditingController();
    String network = 'mtn';
    await showAppBottomSheet(
      context,
      title: 'Paiement Mobile Money',
      child: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: ['mtn', 'moov', 'celtiis_bj', 'coris'].map((n) {
                final selected = network == n;
                return ChoiceChip(
                  label: Text(n),
                  selected: selected,
                  onSelected: (_) => setSheetState(() => network = n),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Numéro Mobile Money'), keyboardType: TextInputType.phone),
            SizedBox(height: 16),
            PrimaryButton(
              label: 'Payer',
              onPressed: () async {
                try {
                  await PaymentService().payWithFeexPay(rideId: _rideId, network: network, phoneNumber: phoneCtrl.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                    context.go('/client/tracking/ride/$_rideId');
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _payVerzapay() async {
    Navigator.pop(context);
    try {
      await PaymentService().payWithVerzapay(rideId: _rideId, phoneNumber: '');
      if (mounted) context.go('/client/tracking/ride/$_rideId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Réserver une course')),
      body: Column(
        children: [
          Expanded(
            child: _pickup == null
                ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                : GoogleMap(
                    initialCameraPosition: CameraPosition(target: _pickup!, zoom: 15),
                    onMapCreated: (c) => _mapController = c,
                    myLocationEnabled: true,
                    onTap: (latLng) => setState(() => _dropoff = latLng),
                    markers: {
                      Marker(markerId: MarkerId('pickup'), position: _pickup!, infoWindow: InfoWindow(title: 'Départ')),
                      if (_dropoff != null)
                        Marker(markerId: MarkerId('dropoff'), position: _dropoff!, infoWindow: InfoWindow(title: 'Arrivée')),
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Touchez la carte pour choisir la destination', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['moto', 'voiture'].map((v) {
                    final selected = _vehicleType == v;
                    return ChoiceChip(
                      label: Text(v),
                      selected: selected,
                      onSelected: (_) => setState(() => _vehicleType = v),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),
                PrimaryButton(label: 'Estimer et réserver', onPressed: _dropoff == null ? null : _requestRide, loading: _requesting),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
