import 'package:flutter/material.dart';
import '../services/maps/maps_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';

class PickedAddress {
  final double lat;
  final double lng;
  final String label;
  PickedAddress({required this.lat, required this.lng, required this.label});
}

/// Bottom sheet permettant de saisir une adresse manuellement (recherche OSM)
/// ou d'utiliser la position GPS actuelle. Utilisé pour l'adresse de
/// livraison/départ, même si la position automatique reste la valeur par
/// défaut — l'utilisateur peut toujours la corriger.
Future<PickedAddress?> showAddressPicker(BuildContext context, {String title = 'Choisir une adresse'}) {
  return showModalBottomSheet<PickedAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddressPickerSheet(title: title),
  );
}

class _AddressPickerSheet extends StatefulWidget {
  final String title;
  const _AddressPickerSheet({required this.title});

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _mapsService = MapsService();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _locating = false;

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final res = await _mapsService.searchAddress(query);
      setState(() => _results = res);
    } catch (_) {
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (mounted) {
        Navigator.pop(
          context,
          PickedAddress(lat: pos.latitude, lng: pos.longitude, label: 'Ma position actuelle'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Localisation indisponible : $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            InkWell(
              onTap: _locating ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _locating
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.my_location_rounded, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    const Text('Utiliser ma position actuelle', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(hintText: 'Ou tapez une adresse...', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) {
                if (v.trim().length >= 3) _search(v.trim());
              },
            ),
            const SizedBox(height: 10),
            Flexible(
              child: _searching
                  ? Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        return ListTile(
                          leading: Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
                          title: Text(r['label'], maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(
                            context,
                            PickedAddress(lat: r['lat'], lng: r['lng'], label: r['label']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
