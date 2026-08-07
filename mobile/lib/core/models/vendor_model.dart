import 'geo_point_model.dart';

class VendorModel {
  final String id;
  final String ownerId;
  final String businessName;
  final String category; // resto | shop
  final String status; // pending | active | suspended | rejected
  final num commission;
  final LivraGeoPoint position;
  final String address;
  final String? coverImageUrl;
  final String? logoUrl;
  final String? description;
  final num? deliveryFee;
  final double rating;
  final bool isOpen;
  final num completedCount;
  final bool boosted;

  VendorModel({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.category,
    required this.status,
    required this.commission,
    required this.position,
    required this.address,
    this.coverImageUrl,
    this.logoUrl,
    this.description,
    this.deliveryFee,
    this.rating = 0,
    this.isOpen = false,
    this.completedCount = 0,
    this.boosted = false,
  });

  factory VendorModel.fromMap(String id, Map<String, dynamic> map) => VendorModel(
        id: id,
        ownerId: map['ownerId'] ?? '',
        businessName: map['businessName'] ?? '',
        category: map['category'] ?? 'shop',
        status: map['status'] ?? 'pending',
        commission: map['commission'] ?? 0,
        position: LivraGeoPoint.fromMap(map['position'] ?? {}),
        address: map['address'] ?? '',
        coverImageUrl: map['coverImageUrl'],
        logoUrl: map['logoUrl'],
        description: map['description'],
        deliveryFee: map['deliveryFee'],
        rating: (map['rating'] ?? 0).toDouble(),
        isOpen: map['isOpen'] ?? false,
        completedCount: map['completedCount'] ?? 0,
        boosted: map['boosted'] ?? false,
      );
}
