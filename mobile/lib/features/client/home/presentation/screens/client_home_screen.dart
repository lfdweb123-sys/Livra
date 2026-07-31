import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/models/vendor_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';

class _Service {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Service(this.label, this.icon, this.onTap);
}

class ClientHomeScreen extends StatefulWidget {
  ClientHomeScreen({super.key});
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
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: Duration(milliseconds: 300));
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
        title: Text('Livra', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.notifications_none_rounded), onPressed: () => context.push('/notifications')),
          IconButton(icon: Icon(Icons.account_circle_outlined), onPressed: () => context.push('/client/profile')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVendors,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
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
                            SizedBox(height: 6),
                            Text(s.label, style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 24),
            Row(
              key: _listKey,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _categoryFilter == 'resto' ? 'Restaurants près de vous' : 'Restaurants & boutiques près de vous',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_categoryFilter != null)
                  TextButton(onPressed: () => _filterByCategory(null), child: Text('Tout voir', style: TextStyle(color: AppColors.gold))),
              ],
            ),
            SizedBox(height: 12),
            if (_vendors == null)
              SkeletonCardList(count: 3)
            else if (_vendors!.isEmpty)
              EmptyState(icon: Icons.storefront_outlined, message: 'Aucun vendeur actif pour le moment.')
            else
              ..._vendors!.map((v) => Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(12),
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
    );
  }
}
