import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/storage/upload_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

/// Candidature vendeur — documents obligatoires pour vérification
/// d'identité par l'admin avant activation (même logique que les livreurs).
class ApplyVendorScreen extends StatefulWidget {
  final String? initialCategory;
  const ApplyVendorScreen({super.key, this.initialCategory});
  @override
  State<ApplyVendorScreen> createState() => _ApplyVendorScreenState();
}

class _ApplyVendorScreenState extends State<ApplyVendorScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  late String _category = widget.initialCategory ?? 'resto';
  final Map<String, File> _docs = {};
  bool _loading = false;

  static const _requiredDocs = {
    'cni': "Pièce d'identité (CNI/passeport)",
    'photoLocal': 'Photo de la boutique/restaurant',
  };
  static const _optionalDocs = {
    'registreCommerce': 'Registre de commerce (si vous en avez un)',
  };

  Future<void> _pickDoc(String key) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _docs[key] = File(picked.path));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renseignez le nom et l\'adresse.')));
      return;
    }
    if (_docs.length < _requiredDocs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les documents sont requis pour la vérification d'identité.")),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uploadService = UploadService();
      final documents = <String, String>{};
      for (final entry in _docs.entries) {
        documents[entry.key] = await uploadService.uploadFile(entry.value, folder: 'vendors');
      }
      final position = await LocationService().getCurrentPosition();
      await ApiClient.instance.post(ApiConstants.vendors, data: {
        'businessName': _nameCtrl.text.trim(),
        'category': _category,
        'address': _addressCtrl.text.trim(),
        'lat': position.latitude,
        'lng': position.longitude,
        'documents': documents,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Candidature envoyée ! Notre équipe vérifie votre identité avant l'activation."),
        ));
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Devenir vendeur')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Nom de la boutique / restaurant')),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(hintText: 'Adresse')),
            const SizedBox(height: 16),
            Text('Catégorie', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['resto', 'shop'].map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Documents (vérification d\'identité)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Requis avant activation par notre équipe.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 8),
            ..._requiredDocs.entries.map((e) => Card(
                  child: ListTile(
                    title: Text(e.value),
                    trailing: Icon(
                      _docs.containsKey(e.key) ? Icons.check_circle : Icons.camera_alt,
                      color: _docs.containsKey(e.key) ? AppColors.success : AppColors.textSecondary,
                    ),
                    onTap: () => _pickDoc(e.key),
                  ),
                )),
            ..._optionalDocs.entries.map((e) => Card(
                  child: ListTile(
                    title: Text(e.value),
                    subtitle: const Text('Optionnel', style: TextStyle(fontSize: 11)),
                    trailing: Icon(
                      _docs.containsKey(e.key) ? Icons.check_circle : Icons.camera_alt_outlined,
                      color: _docs.containsKey(e.key) ? AppColors.success : AppColors.textSecondary,
                    ),
                    onTap: () => _pickDoc(e.key),
                  ),
                )),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Envoyer ma candidature', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
