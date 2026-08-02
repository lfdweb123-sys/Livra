import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/discovery_service.dart';
import '../../../../../core/services/app_content_service.dart';
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
  List<Map<String, dynamic>> _featured = [];
  Timer? _featuredTimer;
  final _discoveryService = DiscoveryService();
  List<String> _bannerImages = ['assets/images/banners/banner1.png', 'assets/images/banners/banner2.png'];
  bool _bannerIsNetwork = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _loadFeatured();
    _loadAppContent();
    _featuredTimer = Timer.periodic(const Duration(minutes: 1), (_) => _loadFeatured());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPartnerPopup());
  }

  Future<void> _loadAppContent() async {
    final config = await AppContentService().fetch();
    if (!mounted) return;
    if (config.bannersEnabled && config.banners.isNotEmpty) {
      setState(() {
        _bannerImages = config.banners;
        _bannerIsNetwork = true;
      });
    } else if (!config.bannersEnabled) {
      setState(() => _bannerImages = []);
    }
  }

  Future<void> _maybeShowPartnerPopup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final vendorSnap = await FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).get();
    if (vendorSnap.docs.isNotEmpty) return;
    final driverSnap = await FirebaseFirestore.instance.collection('drivers').where('ownerId', isEqualTo: uid).limit(1).get();
    if (driverSnap.docs.isNotEmpty) return;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.handshake_rounded, color: AppColors.gold, size: 40),
              const SizedBox(height: 16),
              const Text('Devenez partenaire Livra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Livreur, chauffeur ou vendeur ? Gagnez un revenu complémentaire en rejoignant Livra.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/apply-driver');
                },
                child: const Text('Devenir livreur'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/apply-vendor');
                },
                child: const Text('Devenir vendeur'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Plus tard', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    try {
      final items = await _discoveryService.featuredProducts();
      if (mounted) setState(() => _featured = items);
      for (final item in items) {
        if (item['sponsored'] == true && item['campaignId'] != null) {
          _discoveryService.trackImpression(item['campaignId']);
        }
      }
    } catch (_) {}
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
              AutoBannerCarousel(imagePaths: _bannerImages, isNetwork: _bannerIsNetwork),
              const SizedBox(height: 18),
              if (_featured.isNotEmpty) ...[
                Text('Découverte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _featured.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final item = _featured[i];
                      return GestureDetector(
                        onTap: () {
                          if (item['sponsored'] == true && item['campaignId'] != null) {
                            _discoveryService.trackClick(item['campaignId']);
                          }
                          if (item['vendorId'] != null) context.push('/client/vendor/${item['vendorId']}');
                        },
                        child: Container(
                          width: 130,
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                    child: item['imageUrl'] != null
                                        ? Image.network(item['imageUrl'], height: 90, width: 130, fit: BoxFit.cover)
                                        : Container(height: 90, width: 130, color: AppColors.surfaceElevated),
                                  ),
                                  if (item['sponsored'] == true)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Sponsorisé', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                                      ),
                                    ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('${item['price']} XOF', style: TextStyle(fontSize: 11, color: AppColors.gold)),
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
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 8),
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
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceElevated,
                          backgroundImage: v.logoUrl != null ? NetworkImage(v.logoUrl!) : null,
                          child: v.logoUrl == null ? Text(v.businessName.isNotEmpty ? v.businessName[0] : '?') : null,
                        ),
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
}
