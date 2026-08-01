import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/models/vendor_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/auto_banner_carousel.dart';

class _Service {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Service(this.label, this.icon, this.onTap);
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  List<VendorModel>? _vendors;
  String? _categoryFilter; // null = tout, 'resto' = Nourriture, 'shop' = boutiques
  final _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    try {
      final query = {'status': 'active', if (_categoryFilter != null) 'category': _categoryFilter!};
      final res = await ApiClient.instance.get(ApiConstants.vendors, query: query);
      final items = (res['items'] as List).map((e) => VendorModel.fromMap(e['id'], e)).toList();
      if (mounted) setState(() => _vendors = items);
    } catch (_) {
      if (mounted) setState(() => _vendors = []);
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _categoryFilter = category;
      _vendors = null;
    });
    _loadVendors();
    final ctx = _listKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final services = [
      _Service('Colis', Icons.inventory_2_rounded, () => context.push('/client/checkout', extra: {'type': 'colis', 'items': []})),
      _Service('Nourriture', Icons.restaurant_rounded, () => _filterByCategory('resto')),
      _Service('Moto-taxi', Icons.two_wheeler_rounded, () => context.push('/client/ride', extra: {'vehicleType': 'moto'})),
      _Service('Voiture-taxi', Icons.local_taxi_rounded, () => context.push('/client/ride', extra: {'vehicleType': 'voiture'})),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 40, full: true),
        actions: [
          notificationBellAction(context),
          IconButton(icon: const Icon(Icons.account_circle_outlined), onPressed: () => context.push('/client/profile')),
        ],
      ),
      body: swipeableTab(
        context: context,
        currentIndex: 0,
        child: RefreshIndicator(
          onRefresh: _loadVendors,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                onTap: () => context.push('/client/search'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text('Rechercher restaurants, boutiques...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                children: services
                    .map((s) => GestureDetector(
                          onTap: s.onTap,
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                child: Icon(s.icon, color: AppColors.gold),
                              ),
                              const SizedBox(height: 6),
                              Text(s.label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              AutoBannerCarousel(imagePaths: [
                'assets/images/banners/banner1.png',
                'assets/images/banners/banner2.png',
              ]),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  children: [
                    _smallLink(context, 'Devenir livreur / chauffeur', '/apply-driver'),
                    _smallLink(context, 'Devenir vendeur', '/apply-vendor'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                key: _listKey,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _categoryFilter == 'resto' ? 'Restaurants près de vous' : 'Restaurants & boutiques près de vous',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_categoryFilter != null)
                    TextButton(onPressed: () => _filterByCategory(null), child: Text('Tout voir', style: TextStyle(color: AppColors.gold))),
                ],
              ),
              const SizedBox(height: 12),
              if (_vendors == null)
                const SkeletonCardList(count: 3)
              else if (_vendors!.isEmpty)
                const EmptyState(icon: Icons.storefront_outlined, message: 'Aucun vendeur actif pour le moment.')
              else
                ..._vendors!.map((v) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(backgroundColor: AppColors.surfaceElevated, child: Text(v.businessName.isNotEmpty ? v.businessName[0] : '?')),
                        title: Text(v.businessName),
                        subtitle: Text(v.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star, size: 14, color: AppColors.gold),
                          Text(v.rating.toStringAsFixed(1)),
                        ]),
                        onTap: () => context.push('/client/vendor/${v.id}'),
                      ),
                    )),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _smallLink(BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold, decoration: TextDecoration.underline),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.gold),
        ],
      ),
    );
  }
}
