import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/friendly_error.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/payment/payment_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/phone_number_field.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/address_picker_sheet.dart';
import '../../../../../core/widgets/driver_picker.dart';
import '../../../../../core/widgets/debounced_button.dart';
import '../../../../../core/widgets/cash_service_fee_sheet.dart';
import '../../../../../core/services/payment/verzapay_checkout_flow.dart';

class RequestRideScreen extends StatefulWidget {
  final String? initialVehicleType;
  const RequestRideScreen({super.key, this.initialVehicleType});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  final _mapController = MapController();
  ll.LatLng? _pickup;
  String _pickupLabel = 'Ma position actuelle';
  ll.LatLng? _dropoff;
  String? _dropoffLabel;
  late String _vehicleType;
  bool _requesting = false;
  String? _rideId;
  num _serviceFee = 0;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.initialVehicleType ?? 'moto';
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      if (mounted) setState(() => _pickup = ll.LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _pickPickupAddress() async {
    final result = await showAddressPicker(context, title: 'Adresse de départ');
    if (result != null) {
      setState(() {
        _pickup = ll.LatLng(result.lat, result.lng);
        _pickupLabel = result.label;
      });
      _mapController.move(_pickup!, 15);
    }
  }

  Future<void> _pickDropoffAddress() async {
    final result = await showAddressPicker(context, title: 'Destination');
    if (result != null) {
      setState(() {
        _dropoff = ll.LatLng(result.lat, result.lng);
        _dropoffLabel = result.label;
      });
      _mapController.move(_dropoff!, 15);
    }
  }

  Future<void> _requestRide() async {
    if (_pickup == null || _dropoff == null) return;

    // Propose un chauffeur/taxi-moto actif à proximité — le client peut en
    // choisir un précis, un chauffeur hors application (numéro transmis à
    // l'admin), ou ne rien préciser (laisser l'appli proposer la course à
    // tous les chauffeurs disponibles comme avant).
    final pickResult = await pickDriver(
      context,
      lat: _pickup!.latitude,
      lng: _pickup!.longitude,
      vehicleType: _vehicleType,
      title: 'Choisir un chauffeur',
    );

    setState(() => _requesting = true);
    try {
      final res = await ApiClient.instance.post(ApiConstants.rides, data: {
        'pickupLocation': {
          'geopoint': {'latitude': _pickup!.latitude, 'longitude': _pickup!.longitude},
          'label': _pickupLabel,
        },
        'dropoffLocation': {
          'geopoint': {'latitude': _dropoff!.latitude, 'longitude': _dropoff!.longitude},
          'label': _dropoffLabel,
        },
        'vehicleType': _vehicleType,
        if (pickResult.driverId != null) 'preferredDriverId': pickResult.driverId,
        if (pickResult.offPlatformPhone != null) 'offPlatformDriverPhone': pickResult.offPlatformPhone,
      });
      _rideId = res['id'];
      _serviceFee = res['serviceFee'] ?? 0;
      if (mounted) {
        await showAppBottomSheet(
          context,
          title: 'Course estimée',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course: ${res['basePrice']} XOF'),
              Text('Frais de service (${res['serviceFeePercent'] ?? 5}%): ${res['serviceFee']} XOF'),
              const Divider(),
              Text('Prix total: ${res['price']} XOF', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Distance: ${res['distanceKm']} km'),
              Text('ETA: ${res['etaMinutes']} min'),
              const SizedBox(height: 16),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
            title: const Text('Mobile Money'),
            onTap: _payFeexpay,
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: const Text('Carte bancaire / International'),
            onTap: _payVerzapay,
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: AppColors.gold),
            title: const Text('Portefeuille Livra'),
            onTap: _payWallet,
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined, color: AppColors.gold),
            title: const Text('Espèces à bord'),
            subtitle: const Text('Payez directement le chauffeur', style: TextStyle(fontSize: 12)),
            onTap: _payCash,
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
                  labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            PhoneNumberField(onChanged: (v) => phoneCtrl.text = v),
            const SizedBox(height: 16),
            DebouncedButton(
              label: 'Payer',
              onPressed: () async {
                if (phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renseignez votre numéro Mobile Money.')));
                  return;
                }
                try {
                  await PaymentService().payWithFeexPay(
                    rideId: _rideId,
                    network: network,
                    phoneNumber: phoneCtrl.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    context.go('/client/tracking/ride/$_rideId');
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
    await payWithVerzapayFlow(
      context,
      initiate: (phone) => PaymentService().payWithVerzapay(rideId: _rideId, phoneNumber: phone),
      onSuccess: () {
        if (mounted) context.go('/client/tracking/ride/$_rideId');
      },
    );
  }

  Future<void> _payWallet() async {
    Navigator.pop(context);
    try {
      await ApiClient.instance.patch('/api/rides/$_rideId', data: {'paymentMethod': 'wallet'});
      if (mounted) context.go('/client/tracking/ride/$_rideId');
    } catch (e) {
      final msg = e.toString().contains('insufficient_balance')
          ? 'Solde insuffisant sur votre portefeuille Livra. Déposez des fonds ou choisissez un autre moyen de paiement.'
          : friendlyError(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _payCash() async {
    Navigator.pop(context);
    await showCashServiceFeeSheet(
      context,
      payServiceFeeEndpoint: '/api/rides/$_rideId/pay-service-fee',
      serviceFee: _serviceFee,
      onSuccess: () {
        if (mounted) context.go('/client/tracking/ride/$_rideId');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver une course')),
      body: Column(
        children: [
          Expanded(
            child: _pickup == null
                ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pickup!,
                      initialZoom: 15,
                      onTap: (tapPosition, point) => setState(() => _dropoff = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.lfd.livra',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: _pickup!,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.trip_origin_rounded, color: AppColors.success, size: 30),
                        ),
                        if (_dropoff != null)
                          Marker(
                            point: _dropoff!,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.location_on_rounded, color: AppColors.danger, size: 36),
                          ),
                      ]),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickPickupAddress,
                  child: Row(
                    children: [
                      Icon(Icons.trip_origin_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pickupLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDropoffAddress,
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dropoff == null ? 'Choisir la destination (obligatoire)' : 'Destination sélectionnée — touchez pour modifier',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: _dropoff == null ? AppColors.danger : AppColors.textSecondary),
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('Ou touchez la carte pour choisir la destination', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['moto', 'voiture'].map((v) {
                    final selected = _vehicleType == v;
                    return ChoiceChip(
                      avatar: Icon(
                        v == 'moto' ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                        size: 18,
                        color: selected ? Colors.black : AppColors.textSecondary,
                      ),
                      label: Text(v == 'moto' ? 'Taxi-moto' : 'Voiture'),
                      selected: selected,
                      onSelected: (_) => setState(() => _vehicleType = v),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Estimer et réserver', onPressed: _dropoff == null ? null : _requestRide, loading: _requesting),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
