class ProductModel {
  final String id;
  final String name;
  final String description;
  final num price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final bool pinned;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.pinned = false,
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
      );
}
