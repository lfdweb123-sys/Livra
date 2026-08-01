import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/models/vendor_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<VendorModel>? _allVendors;
  List<VendorModel> _vendorResults = [];
  List<Map<String, dynamic>>? _productResults;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _searchProducts('');
  }

  Future<void> _loadVendors() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.vendors, query: {'status': 'active', 'limit': 50});
      final items = (res['items'] as List).map((e) => VendorModel.fromMap(e['id'], e)).toList();
      if (mounted) setState(() { _allVendors = items; _vendorResults = items; });
    } catch (_) {
      if (mounted) setState(() { _allVendors = []; _vendorResults = []; });
    }
  }

  Future<void> _searchProducts(String query) async {
    setState(() => _loadingProducts = true);
    try {
      final res = await ApiClient.instance.get('/api/products/search', query: {'q': query});
      if (mounted) setState(() => _productResults = List<Map<String, dynamic>>.from(res['items'] ?? []));
    } catch (_) {
      if (mounted) setState(() => _productResults = []);
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _onQueryChanged(String query) {
    if (_allVendors != null) {
      final q = query.trim().toLowerCase();
      setState(() {
        _vendorResults = q.isEmpty
            ? _allVendors!
            : _allVendors!.where((v) => v.businessName.toLowerCase().contains(q) || v.category.toLowerCase().contains(q)).toList();
      });
    }
    _searchProducts(query);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    final nothingFound = _allVendors != null && _productResults != null && _vendorResults.isEmpty && _productResults!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Restaurants, boutiques, produits...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: (_allVendors == null || _productResults == null)
          ? const SkeletonCardList()
          : nothingFound
              ? const EmptyState(icon: Icons.search_off_rounded, message: 'Aucun résultat pour cette recherche.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_productResults!.isNotEmpty) ...[
                      Text(hasQuery ? 'Produits' : 'Suggestions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _productResults!.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final p = _productResults![i];
                            return GestureDetector(
                              onTap: () {
                                if (p['vendorId'] != null) context.push('/client/vendor/${p['vendorId']}');
                              },
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                      child: p['imageUrl'] != null
                                          ? Image.network(p['imageUrl'], height: 80, width: 120, fit: BoxFit.cover)
                                          : Container(height: 80, width: 120, color: AppColors.surfaceElevated),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          Text('${p['price']} XOF', style: TextStyle(fontSize: 11, color: AppColors.gold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_vendorResults.isNotEmpty) ...[
                      Text('Restaurants & boutiques', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._vendorResults.map((v) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.surfaceElevated,
                                child: Text(v.businessName.isNotEmpty ? v.businessName[0] : '?'),
                              ),
                              title: Text(v.businessName),
                              subtitle: Text(v.category == 'resto' ? 'Restaurant' : 'Boutique'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.star, size: 14, color: AppColors.gold),
                                Text(v.rating.toStringAsFixed(1)),
                              ]),
                              onTap: () => context.push('/client/vendor/${v.id}'),
                            ),
                          )),
                    ],
                  ],
                ),
    );
  }
}
