import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';

class VendorDetailScreen extends StatefulWidget {
  final String vendorId;
  VendorDetailScreen({super.key, required this.vendorId});
  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  List<ProductModel>? _products;
  final Map<String, int> _cart = {};
  Map<String, ProductModel> _catalog = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.get('/api/vendors/${widget.vendorId}/products');
    final items = (res['items'] as List).map((e) => ProductModel.fromMap(e['id'], e)).toList();
    setState(() {
      _products = items;
      _catalog = {for (final p in items) p.id: p};
    });
  }

  num get _total => _cart.entries.fold(0, (sum, e) => sum + (_catalog[e.key]?.price ?? 0) * e.value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Catalogue')),
      body: _products == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _products!.length,
              itemBuilder: (context, i) {
                final p = _products![i];
                final qty = _cart[p.id] ?? 0;
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: TextStyle(fontWeight: FontWeight.w600)),
                              Text('${p.price} XOF', style: TextStyle(color: AppColors.gold)),
                            ],
                          ),
                        ),
                        if (qty == 0)
                          IconButton(
                            icon: Icon(Icons.add_circle, color: AppColors.gold),
                            onPressed: () => setState(() => _cart[p.id] = 1),
                          )
                        else
                          Row(
                            children: [
                              IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _cart[p.id] = qty - 1 <= 0 ? 0 : qty - 1)),
                              Text('$qty'),
                              IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => setState(() => _cart[p.id] = qty + 1)),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
      bottomNavigationBar: _total > 0
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => context.push('/client/checkout', extra: {
                    'vendorId': widget.vendorId,
                    'type': 'nourriture',
                    'items': _cart.entries.where((e) => e.value > 0).map((e) => {'productId': e.key, 'qty': e.value}).toList(),
                  }),
                  child: Text('Commander — $_total XOF'),
                ),
              ),
            )
          : null,
    );
  }
}
