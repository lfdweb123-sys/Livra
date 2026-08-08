import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/constants/boost_tier_colors.dart';
import '../../../../../core/widgets/zoomable_image.dart';

const _vehicleLabels = {
  'moto': 'Taxi-moto',
  'voiture': 'Chauffeur',
  'coursier': 'Livreur / Coursier',
};

/// Annuaire de tous les livreurs/coursiers/chauffeurs/taxi-motos
/// actuellement actifs et en ligne — pas limité à un rayon géographique
/// (voir la recherche géo lors d'une commande pour ça).
class ActiveDriversScreen extends StatefulWidget {
  const ActiveDriversScreen({super.key});
  @override
  State<ActiveDriversScreen> createState() => _ActiveDriversScreenState();
}

class _ActiveDriversScreenState extends State<ActiveDriversScreen> {
  List<dynamic>? _drivers;
  String? _vehicleFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _drivers = null);
    try {
      final res = await ApiClient.instance.get('/api/drivers/directory', query: {
        if (_vehicleFilter != null) 'vehicleType': _vehicleFilter,
      });
      if (mounted) setState(() => _drivers = res['items']);
    } catch (_) {
      if (mounted) setState(() => _drivers = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Livreurs actifs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _vehicleFilter == null,
                  onSelected: (_) { setState(() => _vehicleFilter = null); _load(); },
                  selectedColor: AppColors.gold,
                ),
                ..._vehicleLabels.entries.map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _vehicleFilter == e.key,
                      onSelected: (_) { setState(() => _vehicleFilter = e.key); _load(); },
                      selectedColor: AppColors.gold,
                    )),
              ],
            ),
          ),
          Expanded(
            child: _drivers == null
                ? SkeletonCardList()
                : _drivers!.isEmpty
                    ? EmptyState(icon: Icons.two_wheeler_outlined, message: 'Aucun livreur actif pour le moment.')
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.gold,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _drivers!.length,
                          itemBuilder: (context, i) {
                            final d = _drivers![i] as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: d['photoUrl'] != null
                                    ? ZoomableImage(imageUrl: d['photoUrl'], width: 48, height: 48, borderRadius: BorderRadius.circular(24))
                                    : CircleAvatar(radius: 24, backgroundColor: AppColors.surfaceElevated, child: Icon(Icons.person, color: AppColors.textSecondary)),
                                title: Row(
                                  children: [
                                    Flexible(child: Text(d['name'] ?? 'Livreur Livra', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    if (d['boosted'] == true) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.bolt_rounded, size: 14, color: boostTierColor(d['boostTier'])),
                                    ],
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                                    const SizedBox(width: 2),
                                    Text('${(d['rating'] ?? 0).toStringAsFixed(1)} · ', style: const TextStyle(fontSize: 12)),
                                    Text(_vehicleLabels[d['vehicleType']] ?? d['vehicleType'] ?? '', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 8, color: AppColors.success),
                                      const SizedBox(width: 4),
                                      Text('En ligne', style: TextStyle(color: AppColors.success, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                onTap: () => context.push('/driver/detail/${d['id']}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
