import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import '../constants/off_platform_notice.dart';
import 'app_bottom_sheet.dart';
import 'phone_number_field.dart';
import 'primary_button.dart';
import 'zoomable_image.dart';

const _vehicleLabels = {
  'moto': 'Taxi-moto',
  'voiture': 'Chauffeur',
  'coursier': 'Livreur / Coursier',
};

/// Résultat du choix de livreur : soit un livreur de l'application
/// ([driverId]), soit un livreur hors application dont on a précisé le
/// numéro ([offPlatformPhone] — transmis à l'admin pour suivi), soit rien
/// du tout (les deux à null).
class DriverPickResult {
  final String? driverId;
  final String? offPlatformPhone;
  const DriverPickResult({this.driverId, this.offPlatformPhone});
  bool get isEmpty => driverId == null && offPlatformPhone == null;
}

/// Ouvre la liste des livreurs/chauffeurs actifs à proximité et laisse
/// l'utilisateur (client ou vendeur) choisir librement : un livreur de
/// l'application, un livreur hors application (en précisant son numéro,
/// transmis à l'admin pour suivi), ou ne rien préciser du tout.
Future<DriverPickResult> pickDriver(
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

  final result = await showAppBottomSheet<DriverPickResult>(
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
                  title: Row(
                    children: [
                      Flexible(child: Text(d['name'] ?? 'Livreur Livra', style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (d['boosted'] == true) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.bolt_rounded, size: 14, color: AppColors.gold),
                      ],
                    ],
                  ),
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
                    onPressed: () => Navigator.of(context).pop(DriverPickResult(driverId: d['id'])),
                    child: const Text('Choisir'),
                  ),
                  onTap: () async {
                    final picked = await context.push<Map<String, dynamic>>(
                      '/driver/detail/${d['id']}',
                      extra: {'selectable': true},
                    );
                    if (picked != null && context.mounted) {
                      Navigator.of(context).pop(DriverPickResult(driverId: picked['id']));
                    }
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
          child: OutlinedButton.icon(
            onPressed: () async {
              final phone = await _promptOffPlatformPhone(context);
              if (phone != null && context.mounted) {
                Navigator.of(context).pop(DriverPickResult(offPlatformPhone: phone));
              }
            },
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Livreur hors application (préciser son numéro)'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(const DriverPickResult()),
            child: const Text('Ne rien préciser pour l\'instant'),
          ),
        ),
      ],
    ),
  );
  return result ?? const DriverPickResult();
}

Future<String?> _promptOffPlatformPhone(BuildContext context) async {
  final phoneCtrl = TextEditingController();
  return showAppBottomSheet<String?>(
    context,
    title: 'Livreur hors application',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Renseignez le numéro du livreur que vous utilisez en dehors de Livra — '
          'transmis à notre équipe pour le suivi. Rappel : ce trajet ne relève pas de '
          'la responsabilité de Livra (voir conditions d\'utilisation).',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        PhoneNumberField(onChanged: (v) => phoneCtrl.text = v),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Confirmer',
          onPressed: () {
            if (phoneCtrl.text.trim().length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Renseignez un numéro valide.')));
              return;
            }
            Navigator.of(context).pop(phoneCtrl.text.trim());
          },
        ),
      ],
    ),
  );
}
