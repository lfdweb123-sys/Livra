import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/storage/upload_service.dart';
import '../../../../core/services/storage/image_compression_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

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
  String? _compressingKey;

  static const _requiredDocs = {
    'cni': "Pièce d'identité (CNI/passeport)",
    'photoLocal': 'Photo de la boutique/restaurant',
  };
  static const _optionalDocs = {
    'registreCommerce': 'Registre de commerce (si vous en avez un)',
  };

  Future<void> _pickDoc(String key) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    // Compression automatique — évite les envois lents/qui échouent sur
    // connexion faible (photos caméra brutes souvent 3-8 Mo).
    setState(() => _compressingKey = key);
    final compressed = await ImageCompressionService().compress(File(picked.path), targetSizeBytes: 300 * 1024);
    if (mounted) {
      setState(() {
        _docs[key] = compressed;
        _compressingKey = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renseignez le nom et l\'adresse.')));
      return;
    }
    if (_docs.length < _requiredDocs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Tous les documents sont requis pour la vérification d'identité.")),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uploadService = UploadService();
      final documents = <String, String>{};
      for (final entry in _docs.entries) {
        documents[entry.key] =
            await uploadService.uploadFile(entry.value, folder: 'vendors');
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
          content: Text(
              "Candidature envoyée ! Notre équipe vérifie votre identité avant l'activation."),
        ));
        context.go('/client/home');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Devenir vendeur'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          children: [
            const SizedBox(height: 4),
            TextField(
                controller: _nameCtrl,
                decoration:
                    _decoration(hint: 'Nom de la boutique / restaurant')),
            const SizedBox(height: 14),
            TextField(
                controller: _addressCtrl,
                decoration: _decoration(hint: 'Adresse')),
            const SizedBox(height: 24),
            Text('Catégorie', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: {'resto': 'Restaurant', 'shop': 'Boutique'}.entries.map((entry) {
                final c = entry.key;
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(entry.value),
                  avatar: selected
                      ? Icon(Icons.check, size: 16, color: Colors.black)
                      : null,
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                      color: selected ? AppColors.gold : AppColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Message explicite, bien visible: une "Boutique" n'est pas
            // limitée à une catégorie de produits précise.
            Text(
              _category == 'shop'
                  ? 'Boutique : vendez tout type de produit ou d\'article — vêtements, électronique, cosmétiques, accessoires, et bien plus. Aucune restriction de catégorie.'
                  : 'Restaurant : vendez vos plats, boissons et menus à la carte.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 28),
            Text(
              'Documents (vérification d\'identité)',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Requis avant activation par notre équipe.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 12),
            ..._requiredDocs.entries.map((e) {
              final done = _docs.containsKey(e.key);
              final compressing = _compressingKey == e.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(e.value,
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: compressing
                      ? Text('Compression en cours…', style: TextStyle(color: AppColors.gold, fontSize: 11))
                      : null,
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.goldSoft,
                    ),
                    child: compressing
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          )
                        : Icon(
                            done ? Icons.check_circle : Icons.camera_alt_outlined,
                            color: done ? AppColors.success : AppColors.textSecondary,
                            size: 20,
                          ),
                  ),
                  onTap: compressing ? null : () => _pickDoc(e.key),
                ),
              );
            }),
            ..._optionalDocs.entries.map((e) {
              final done = _docs.containsKey(e.key);
              final compressing = _compressingKey == e.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(e.value,
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(compressing ? 'Compression en cours…' : 'Optionnel',
                      style: TextStyle(
                          fontSize: 11, color: compressing ? AppColors.gold : AppColors.textSecondary)),
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.goldSoft,
                    ),
                    child: compressing
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          )
                        : Icon(
                            done ? Icons.check_circle : Icons.camera_alt_outlined,
                            color: done ? AppColors.success : AppColors.textSecondary,
                            size: 20,
                          ),
                  ),
                  onTap: compressing ? null : () => _pickDoc(e.key),
                ),
              );
            }),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Envoyer', onPressed: _submit, loading: _loading),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
