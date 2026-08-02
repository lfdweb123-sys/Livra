import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/models/vendor_model.dart';
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
  VendorModel? _vendor;
  final Map<String, int> _cart = {};
  Map<String, ProductModel> _catalog = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vendorRes = await ApiClient.instance.get('/api/vendors/${widget.vendorId}');
    final res = await ApiClient.instance.get('/api/vendors/${widget.vendorId}/products');
    final items = (res['items'] as List).map((e) => ProductModel.fromMap(e['id'], e)).toList();
    items.sort((a, b) => b.pinned == a.pinned ? 0 : (b.pinned ? 1 : -1));
    setState(() {
      _vendor = VendorModel.fromMap(vendorRes['id'], vendorRes);
      _products = items;
      _catalog = {for (final p in items) p.id: p};
    });
  }

  num get _total => _cart.entries.fold(0, (sum, e) => sum + (_catalog[e.key]?.price ?? 0) * e.value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_vendor?.businessName ?? 'Catalogue')),
      body: _products == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _products!.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.surfaceElevated,
                          backgroundImage: _vendor?.logoUrl != null ? NetworkImage(_vendor!.logoUrl!) : null,
                          child: _vendor?.logoUrl == null ? Icon(Icons.storefront_outlined, color: AppColors.textSecondary) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_vendor?.businessName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (_vendor?.address != null)
                                Text(_vendor!.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final p = _products![i - 1];
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
