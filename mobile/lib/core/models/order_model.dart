class OrderItem {
  final String productId;
  final String name;
  final num price;
  final int qty;
  OrderItem({required this.productId, required this.name, required this.price, required this.qty});

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        name: map['name'] ?? '',
        price: map['price'] ?? 0,
        qty: map['qty'] ?? 1,
      );

  Map<String, dynamic> toMap() => {'productId': productId, 'name': name, 'price': price, 'qty': qty};
}

class PriceBreakdown {
  final num subtotal;
  final num deliveryFee;
  final num commission;
  final num total;
  PriceBreakdown({required this.subtotal, required this.deliveryFee, required this.commission, required this.total});

  factory PriceBreakdown.fromMap(Map<String, dynamic> map) => PriceBreakdown(
        subtotal: map['subtotal'] ?? 0,
        deliveryFee: map['deliveryFee'] ?? 0,
        commission: map['commission'] ?? 0,
        total: map['total'] ?? 0,
      );
}

class OrderModel {
  final String id;
  final String clientId;
  final String? vendorId;
  final String? driverId;
  final String type; // colis | nourriture
  final List<OrderItem> items;
  final PriceBreakdown priceBreakdown;
  final String status;
  final String? paymentMethod;
  final String paymentStatus;

  OrderModel({
    required this.id,
    required this.clientId,
    this.vendorId,
    this.driverId,
    required this.type,
    required this.items,
    required this.priceBreakdown,
    required this.status,
    this.paymentMethod,
    required this.paymentStatus,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) => OrderModel(
        id: id,
        clientId: map['clientId'] ?? '',
        vendorId: map['vendorId'],
        driverId: map['driverId'],
        type: map['type'] ?? 'colis',
        items: ((map['items'] ?? []) as List).map((e) => OrderItem.fromMap(e)).toList(),
        priceBreakdown: PriceBreakdown.fromMap(map['priceBreakdown'] ?? {}),
        status: map['status'] ?? 'pending',
        paymentMethod: map['paymentMethod'],
        paymentStatus: map['paymentStatus'] ?? 'pending',
      );
}
