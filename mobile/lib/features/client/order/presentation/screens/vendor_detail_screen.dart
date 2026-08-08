import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/models/vendor_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/zoomable_image.dart';
import '../../../../../core/widgets/share_button.dart';
import '../../../../../core/widgets/report_sheet.dart';

class VendorDetailScreen extends StatefulWidget {
  final String vendorId;
  /// Si fourni, ouvre directement la fiche détail de ce produit dès le
  /// chargement — utilisé quand on arrive depuis un produit suggéré, pour
  /// éviter d'obliger le client à le retrouver et re-cliquer dessus.
  final String? openProductId;
  VendorDetailScreen({super.key, required this.vendorId, this.openProductId});
  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  List<ProductModel>? _products;
  VendorModel? _vendor;
  List<Map<String, dynamic>> _reviews = [];
  final Map<String, int> _cart = {};
  Map<String, ProductModel> _catalog = {};
  // Catégorie sélectionnée pour filtrer le catalogue — null = "Tous".
  // Permet au client de naviguer directement vers ce qui l'intéresse sans
  // parcourir tout le catalogue.
  String? _selectedCategory;

  List<String> get _categories {
    final set = (_products ?? []).map((p) => p.category).where((c) => c.trim().isNotEmpty).toSet().toList();
    set.sort();
    return set;
  }

  List<ProductModel> get _filteredProducts {
    if (_products == null) return [];
    if (_selectedCategory == null) return _products!;
    return _products!.where((p) => p.category == _selectedCategory).toList();
  }

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
    try {
      final reviewsRes = await ApiClient.instance.get('/api/reviews', query: {'targetType': 'vendor', 'targetId': widget.vendorId});
      if (mounted) setState(() => _reviews = List<Map<String, dynamic>>.from(reviewsRes['items'] ?? []));
    } catch (_) {}
    if (widget.openProductId != null && mounted) {
      final p = _catalog[widget.openProductId];
      if (p != null) WidgetsBinding.instance.addPostFrameCallback((_) => _showProductDetail(p));
    }
  }

  void _showReviews() {
    showAppBottomSheet(
      context,
      title: 'Avis clients',
      child: _reviews.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucun avis pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SizedBox(
              height: 350,
              child: ListView.builder(
                itemCount: _reviews.length,
                itemBuilder: (context, i) {
                  final r = _reviews[i];
                  final rating = (r['rating'] ?? 0) as num;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.surfaceElevated,
                              backgroundImage: r['clientPhotoUrl'] != null ? NetworkImage(r['clientPhotoUrl']) : null,
                              child: r['clientPhotoUrl'] == null
                                  ? Text((r['clientName'] as String?)?.substring(0, 1).toUpperCase() ?? '?', style: TextStyle(fontSize: 12))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(r['clientName'] ?? 'Client Livra', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (j) => Icon(
                                j < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.gold,
                                size: 16,
                              )),
                        ),
                        if ((r['comment'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(r['comment'], style: TextStyle(fontSize: 13)),
                        ],
                        const Divider(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  num get _total => _cart.entries.fold(0, (sum, e) => sum + (_catalog[e.key]?.price ?? 0) * e.value);

  /// Détail produit — image zoomable (tap pour agrandir en plein écran) +
  /// description, prix, frais de livraison du vendeur, résumé des avis
  /// (les avis sont enregistrés au niveau du vendeur/livreur, pas produit
  /// par produit — voir POST /api/reviews), et ajout au panier.
  void _showProductDetail(ProductModel p) {
    showAppBottomSheet(
      context,
      child: StatefulBuilder(builder: (context, setSheetState) {
        final qty = _cart[p.id] ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.imageUrl != null)
              ZoomableImage(
                imageUrl: p.imageUrl!,
                height: 200,
                width: double.infinity,
                borderRadius: BorderRadius.circular(16),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                ShareButton(productName: p.name, price: p.price, vendorName: _vendor?.businessName),
              ],
            ),
            const SizedBox(height: 6),
            if (p.description.isNotEmpty)
              Text(p.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${p.price} XOF', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                if (_vendor?.deliveryFee != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.delivery_dining_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text('${_vendor!.deliveryFee} XOF livraison', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showReviews();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${(_vendor?.rating ?? 0).toStringAsFixed(1)} (${_reviews.length} avis) sur ${_vendor?.businessName ?? 'la boutique'}',
                    style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12.5, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (qty == 0)
              PrimaryButton(
                label: 'Ajouter au panier',
                onPressed: () {
                  setState(() => _cart[p.id] = 1);
                  setSheetState(() {});
                },
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() => _cart[p.id] = qty - 1 <= 0 ? 0 : qty - 1);
                      setSheetState(() {});
                    },
                  ),
                  Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() => _cart[p.id] = qty + 1);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bouton "Commander" directement ici, sans avoir à fermer la
              // fiche produit et chercher la barre en bas de la page
              // vendeur — demande explicite: "afficher directement le
              // bouton commander sur la page de detail".
              PrimaryButton(
                label: 'Commander — $_total XOF',
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/client/checkout', extra: {
                    'vendorId': widget.vendorId,
                    'type': 'nourriture',
                    'items': _cart.entries.where((e) => e.value > 0).map((e) => {'productId': e.key, 'qty': e.value}).toList(),
                  });
                },
              ),
            ],
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_vendor?.businessName ?? 'Catalogue'),
        actions: [
          if (_vendor != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Signaler',
              onPressed: () => showReportSheet(
                context,
                againstUid: _vendor!.ownerId,
                againstName: _vendor!.businessName,
              ),
            ),
        ],
      ),
      body: _products == null
          ? SkeletonCardList()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredProducts.length + (_categories.isEmpty ? 1 : 2),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_vendor?.coverImageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(_vendor!.coverImageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                        if (_vendor?.coverImageUrl != null) const SizedBox(height: 14),
                        Row(
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
                        if (_vendor?.description != null && _vendor!.description!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(_vendor!.description!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            InkWell(
                              onTap: _showReviews,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(_vendor?.rating ?? 0).toStringAsFixed(1)} (${_reviews.length} avis)',
                                    style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 13, decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                            if ((_vendor?.completedCount ?? 0) > 0) ...[
                              const SizedBox(width: 14),
                              Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text('${_vendor!.completedCount} ventes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }
                if (_categories.isNotEmpty && i == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('Tous'),
                              selected: _selectedCategory == null,
                              onSelected: (_) => setState(() => _selectedCategory = null),
                              selectedColor: AppColors.gold,
                              labelStyle: TextStyle(color: _selectedCategory == null ? Colors.black : AppColors.textPrimary),
                            ),
                          ),
                          ..._categories.map((c) {
                            final selected = _selectedCategory == c;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: selected,
                                onSelected: (_) => setState(() => _selectedCategory = c),
                                selectedColor: AppColors.gold,
                                labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }
                final p = _filteredProducts[i - (_categories.isEmpty ? 1 : 2)];
                final qty = _cart[p.id] ?? 0;
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showProductDetail(p),
                    child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (p.imageUrl != null) ...[
                          ZoomableImage(
                            imageUrl: p.imageUrl!,
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(width: 12),
                        ],
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
