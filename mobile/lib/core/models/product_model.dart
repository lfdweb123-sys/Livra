class ProductModel {
  final String id;
  final String name;
  final String description;
  final num price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final bool pinned;
  final double rating;
  final int ratingCount;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.pinned = false,
    this.rating = 0,
    this.ratingCount = 0,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) => ProductModel(
        id: id,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        price: map['price'] ?? 0,
        imageUrl: map['imageUrl'],
        category: map['category'] ?? '',
        isAvailable: map['isAvailable'] ?? true,
        pinned: map['pinned'] ?? false,
        rating: (map['rating'] ?? 0).toDouble(),
        ratingCount: map['ratingCount'] ?? 0,
      );
}
