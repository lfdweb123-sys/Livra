import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/zoomable_image.dart';

const _vehicleLabels = {
  'moto': 'Taxi-moto',
  'voiture': 'Chauffeur',
  'coursier': 'Livreur / Coursier',
};

/// Page détail publique d'un livreur/chauffeur/coursier/taxi-moto — même
/// principe que la fiche vendeur (VendorDetailScreen) : photo, nom, note,
/// avis clients, et un bouton d'action selon le contexte (choisir ce
/// livreur, ou le contacter si déjà choisi).
class DriverDetailScreen extends StatefulWidget {
  final String driverId;
  /// Si fourni, affiche "Choisir ce livreur" et retourne l'id au retour de
  /// la page (pop avec résultat) au lieu du bouton contact.
  final bool selectable;
  const DriverDetailScreen({super.key, required this.driverId, this.selectable = false});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.get('/api/drivers/${widget.driverId}');
    if (mounted) setState(() => _driver = res);
    try {
      final reviewsRes = await ApiClient.instance
          .get('/api/reviews', query: {'targetType': 'driver', 'targetId': widget.driverId});
      if (mounted) setState(() => _reviews = List<Map<String, dynamic>>.from(reviewsRes['items'] ?? []));
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final d = _driver;
    return Scaffold(
      appBar: AppBar(title: Text(d?['name'] ?? 'Profil livreur')),
      body: d == null
          ? SkeletonCardList()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: d['photoUrl'] != null
                      ? ZoomableImage(
                          imageUrl: d['photoUrl'],
                          width: 140,
                          height: 140,
                          borderRadius: BorderRadius.circular(70),
                        )
                      : CircleAvatar(
                          radius: 70,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Icon(Icons.person, size: 56, color: AppColors.textSecondary),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(d['name'] ?? 'Livreur Livra',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _vehicleLabels[d['vehicleType']] ?? d['vehicleType'] ?? '',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    children: [
                      InkWell(
                        onTap: _showReviews,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${(d['rating'] ?? 0).toStringAsFixed(1)} (${_reviews.length} avis)',
                              style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                      if ((d['completedCount'] ?? 0) > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text('${d['completedCount']} services', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (d['bio'] != null && (d['bio'] as String).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(d['bio'], style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                ],
                const SizedBox(height: 28),
                if (widget.selectable)
                  PrimaryButton(
                    label: 'Choisir ce livreur',
                    onPressed: () => context.pop({'id': widget.driverId, ...d}),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.push('/contact', extra: {
                      'name': d['name'] ?? 'Votre livreur',
                      'phoneNumber': null,
                      'role': 'Livreur/chauffeur Livra',
                      'calleeUid': d['ownerId'],
                      'photoUrl': d['photoUrl'],
                    }),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text('Contacter ${d['name'] ?? 'le livreur'}'),
                  ),
              ],
            ),
    );
  }
}
