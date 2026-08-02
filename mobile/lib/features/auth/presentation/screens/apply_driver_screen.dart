import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/storage/upload_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

/// Candidature livreur/chauffeur : documents envoyés directement sur le
/// profil driver (pas de flux KYC séparé) — l'admin active depuis le dashboard.
class ApplyDriverScreen extends StatefulWidget {
  final String? initialVehicleType;
  const ApplyDriverScreen({super.key, this.initialVehicleType});
  @override
  State<ApplyDriverScreen> createState() => _ApplyDriverScreenState();
}

class _ApplyDriverScreenState extends State<ApplyDriverScreen> {
  late String _vehicleType = widget.initialVehicleType ?? 'moto';
  final Map<String, File> _docs = {};
  bool _loading = false;

  static const _requiredDocs = {
    'cni': "Pièce d'identité (CNI/passeport)",
    'permis': 'Permis de conduire',
    'assurance': "Assurance du véhicule",
    'photoVehicule': 'Photo du véhicule',
  };

  Future<void> _pickDoc(String key) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _docs[key] = File(picked.path));
  }

  Future<void> _submit() async {
    if (_docs.length < _requiredDocs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les documents sont requis pour la vérification d'identité.")),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uploadService = UploadService();
      final documentsR2 = <String, String>{};
      for (final entry in _docs.entries) {
        documentsR2[entry.key] = await uploadService.uploadFile(entry.value, folder: 'drivers');
      }
      final position = await LocationService().getCurrentPosition();
      await ApiClient.instance.post(ApiConstants.drivers, data: {
        'vehicleType': _vehicleType,
        'lat': position.latitude,
        'lng': position.longitude,
        'documentsR2': documentsR2,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Candidature envoyée ! Vous serez notifié dès validation par notre équipe.'),
        ));
        context.go('/client/home');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Devenir livreur/chauffeur')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: ListView(
          children: [
            Text('Type de véhicule', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['moto', 'voiture', 'coursier'].map((v) {
                final selected = _vehicleType == v;
                return ChoiceChip(
                  label: Text(v),
                  selected: selected,
                  onSelected: (_) => setState(() => _vehicleType = v),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text('Documents (vérification d\'identité)', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 4),
            Text('Tous requis avant activation par notre équipe.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            SizedBox(height: 8),
            ..._requiredDocs.entries.map((e) => Card(
                  child: ListTile(
                    title: Text(e.value),
                    trailing: Icon(_docs.containsKey(e.key) ? Icons.check_circle : Icons.camera_alt, color: _docs.containsKey(e.key) ? AppColors.success : AppColors.textSecondary),
                    onTap: () => _pickDoc(e.key),
                  ),
                )),
            SizedBox(height: 24),
            PrimaryButton(label: 'Envoyer ma candidature', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
