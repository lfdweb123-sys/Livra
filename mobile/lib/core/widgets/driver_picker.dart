import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import '../constants/off_platform_notice.dart';
import 'app_bottom_sheet.dart';
import 'zoomable_image.dart';

const _vehicleLabels = {
  'moto': 'Taxi-moto',
  'voiture': 'Chauffeur',
  'coursier': 'Livreur / Coursier',
};

/// Ouvre la liste des livreurs/chauffeurs actifs à proximité et laisse
/// l'utilisateur (client ou vendeur) choisir librement — ou ne choisir
/// personne pour passer par son propre livreur hors application. Retourne
/// l'id du livreur choisi, ou `null` si aucun choix n'a été fait.
Future<String?> pickDriver(
  BuildContext context, {
  required double lat,
  required double lng,
  String? vehicleType,
  String title = 'Choisir un livreur',
}) async {
  List<dynamic>? drivers;
  try {
    drivers = (await ApiClient.instance.get('/api/drivers/nearby', query: {
      'lat': lat,
      'lng': lng,
      if (vehicleType != null) 'vehicleType': vehicleType,
    }))['items'];
  } catch (_) {
    drivers = [];
  }

  return showAppBottomSheet<String?>(
    context,
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (drivers == null || drivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucun livreur actif à proximité pour le moment.',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: drivers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = drivers![i] as Map<String, dynamic>;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: d['photoUrl'] != null
                      ? ZoomableImage(
                          imageUrl: d['photoUrl'],
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(24),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Icon(Icons.person, color: AppColors.textSecondary),
                        ),
                  title: Text(d['name'] ?? 'Livreur Livra', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(
                    children: [
                      Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                      const SizedBox(width: 2),
                      Text('${(d['rating'] ?? 0).toStringAsFixed(1)} · ', style: TextStyle(fontSize: 12)),
                      Text(_vehicleLabels[d['vehicleType']] ?? d['vehicleType'] ?? '', style: TextStyle(fontSize: 12)),
                      Text(' · ${d['distanceKm']} km', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => context.pop(d['id']),
                    child: const Text('Choisir'),
                  ),
                  onTap: () async {
                    final picked = await context.push<Map<String, dynamic>>(
                      '/driver/detail/${d['id']}',
                      extra: {'selectable': true},
                    );
                    if (picked != null && context.mounted) context.pop(picked['id']);
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        Text(
          offPlatformNotice,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.pop(null),
            child: const Text('Ne pas choisir (livreur hors application)'),
          ),
        ),
      ],
    ),
  );
}
