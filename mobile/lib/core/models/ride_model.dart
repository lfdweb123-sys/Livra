import 'geo_point_model.dart';

class RideModel {
  final String id;
  final String clientId;
  final String? driverId;
  final LivraGeoPoint pickupLocation;
  final LivraGeoPoint dropoffLocation;
  final String vehicleType;
  final String status;
  final num price;
  final double distanceKm;
  final int etaMinutes;
  final String paymentStatus;

  RideModel({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.vehicleType,
    required this.status,
    required this.price,
    required this.distanceKm,
    required this.etaMinutes,
    required this.paymentStatus,
  });

  factory RideModel.fromMap(String id, Map<String, dynamic> map) => RideModel(
        id: id,
        clientId: map['clientId'] ?? '',
        driverId: map['driverId'],
        pickupLocation: LivraGeoPoint.fromMap(map['pickupLocation'] ?? {}),
        dropoffLocation: LivraGeoPoint.fromMap(map['dropoffLocation'] ?? {}),
        vehicleType: map['vehicleType'] ?? 'moto',
        status: map['status'] ?? 'pending',
        price: map['price'] ?? 0,
        distanceKm: (map['distanceKm'] ?? 0).toDouble(),
        etaMinutes: map['etaMinutes'] ?? 0,
        paymentStatus: map['paymentStatus'] ?? 'pending',
      );
}
