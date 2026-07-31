import 'geo_point_model.dart';

class DriverModel {
  final String id;
  final String ownerId;
  final String vehicleType; // moto | voiture | coursier
  final String status;
  final bool isOnline;
  final LivraGeoPoint position;
  final double rating;

  DriverModel({
    required this.id,
    required this.ownerId,
    required this.vehicleType,
    required this.status,
    required this.isOnline,
    required this.position,
    this.rating = 0,
  });

  factory DriverModel.fromMap(String id, Map<String, dynamic> map) => DriverModel(
        id: id,
        ownerId: map['ownerId'] ?? '',
        vehicleType: map['vehicleType'] ?? 'moto',
        status: map['status'] ?? 'pending',
        isOnline: map['isOnline'] ?? false,
        position: LivraGeoPoint.fromMap(map['position'] ?? {}),
        rating: (map['rating'] ?? 0).toDouble(),
      );
}
