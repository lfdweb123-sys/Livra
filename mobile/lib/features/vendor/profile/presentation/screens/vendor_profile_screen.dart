import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/storage/upload_service.dart';
import '../../../../../core/services/storage/image_compression_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/legal_links_section.dart';
import '../../../../../core/widgets/boost_profile_sheet.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});
  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  String? _vendorId;
  final _descCtrl = TextEditingController();
  final _deliveryFeeCtrl = TextEditingController();
  String? _logoUrl;
  String? _coverImageUrl;
  File? _newLogo;
  File? _newCover;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snap = await FirebaseFirestore.instance
        .collection('vendors')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = snap.docs.first.data();
    setState(() {
      _vendorId = snap.docs.first.id;
      _descCtrl.text = data['description'] ?? '';
      _deliveryFeeCtrl.text =
          data['deliveryFee'] != null ? '${data['deliveryFee']}' : '';
      _logoUrl = data['logoUrl'];
      _coverImageUrl = data['coverImageUrl'];
      _loading = false;
    });
  }

  Future<void> _pickImage(bool isLogo) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      final compressed = await ImageCompressionService().compress(File(picked.path));
      if (mounted) {
        setState(() {
          if (isLogo) {
            _newLogo = compressed;
          } else {
            _newCover = compressed;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (_vendorId == null) return;
    setState(() => _saving = true);
    try {
      final upload = UploadService();
      final data = <String, dynamic>{
        'description': _descCtrl.text.trim(),
        if (_deliveryFeeCtrl.text.trim().isNotEmpty)
          'deliveryFee': num.tryParse(_deliveryFeeCtrl.text.trim()),
      };
      if (_newLogo != null)
        data['logoUrl'] = await upload.uploadFile(_newLogo!, folder: 'vendors');
      if (_newCover != null)
        data['coverImageUrl'] =
            await upload.uploadFile(_newCover!, folder: 'vendors');
      await ApiClient.instance.patch('/api/vendors/$_vendorId', data: data);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(
          body:
              Center(child: CircularProgressIndicator(color: AppColors.gold)));
    return Scaffold(
      appBar: AppBar(
          title: const Text('Profil boutique'),
          actions: [notificationBellAction(context)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2.5),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: _newLogo != null
                          ? FileImage(_newLogo!)
                          : (_logoUrl != null
                              ? NetworkImage(_logoUrl!) as ImageProvider
                              : null),
                      child: (_newLogo == null && _logoUrl == null)
                          ? const Icon(Icons.storefront_outlined, size: 32)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.surfaceElevated, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
                onPressed: () => _pickImage(true),
                child: const Text('Changer le logo')),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                image: _newCover != null
                    ? DecorationImage(
                        image: FileImage(_newCover!), fit: BoxFit.cover)
                    : (_coverImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_coverImageUrl!),
                            fit: BoxFit.cover)
                        : null),
              ),
              child: (_newCover == null && _coverImageUrl == null)
                  ? Center(
                      child: Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.textSecondary))
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text('Photo de couverture',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      hintText:
                          'Décrivez votre boutique/restaurant en quelques mots...'),
                ),
                const SizedBox(height: 16),
                Text('Frais de livraison',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _deliveryFeeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      hintText:
                          'Montant fixe en XOF (laisser vide = calcul automatique à la distance)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Enregistrer', onPressed: _save, loading: _saving),
          const SizedBox(height: 12),
          if (_vendorId != null)
            OutlinedButton.icon(
              onPressed: () => showBoostProfileSheet(context, profileType: 'vendor', profileId: _vendorId!),
              icon: Icon(Icons.rocket_launch_outlined, color: AppColors.gold),
              label: Text('Booster mon profil', style: TextStyle(color: AppColors.gold)),
            ),
          const SizedBox(height: 20),
          const LegalLinksSection(),
        ],
      ),
    );
  }
}

