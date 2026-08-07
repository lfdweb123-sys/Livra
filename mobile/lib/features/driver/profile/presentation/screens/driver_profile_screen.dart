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
import 'driver_pricing_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String? _driverId;
  String _vehicleType = 'coursier';
  final _bioCtrl = TextEditingController();
  String? _photoUrl;
  File? _newPhoto;
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
        .collection('drivers')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = snap.docs.first.data();
    setState(() {
      _driverId = snap.docs.first.id;
      _vehicleType = data['vehicleType'] ?? 'coursier';
      _bioCtrl.text = data['bio'] ?? '';
      _photoUrl = data['photoUrl'];
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    final compressed = await ImageCompressionService().compress(File(picked.path));
    if (mounted) setState(() => _newPhoto = compressed);
  }

  Future<void> _save() async {
    if (_driverId == null) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{'bio': _bioCtrl.text.trim()};
      if (_newPhoto != null)
        data['photoUrl'] =
            await UploadService().uploadFile(_newPhoto!, folder: 'drivers');
      await ApiClient.instance.patch('/api/drivers/$_driverId', data: data);
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
          title: const Text('Mon profil'),
          actions: [notificationBellAction(context)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2.5),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: _newPhoto != null
                          ? FileImage(_newPhoto!)
                          : (_photoUrl != null
                              ? NetworkImage(_photoUrl!) as ImageProvider
                              : null),
                      child: (_newPhoto == null && _photoUrl == null)
                          ? const Icon(Icons.person_outline_rounded, size: 38)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickPhoto,
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
                onPressed: _pickPhoto, child: const Text('Changer la photo')),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Présentez-vous en quelques mots...'),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Enregistrer', onPressed: _save, loading: _saving),
          const SizedBox(height: 12),
          if (_driverId != null)
            OutlinedButton.icon(
              onPressed: () => showBoostProfileSheet(context, profileType: 'driver', profileId: _driverId!),
              icon: Icon(Icons.rocket_launch_outlined, color: AppColors.gold),
              label: Text('Booster mon profil', style: TextStyle(color: AppColors.gold)),
            ),
          const SizedBox(height: 12),
          if (_driverId != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverPricingScreen(driverId: _driverId!, vehicleType: _vehicleType),
                ),
              ),
              icon: Icon(Icons.calculate_outlined, color: AppColors.gold),
              label: Text('Mes tarifs de livraison', style: TextStyle(color: AppColors.gold)),
            ),
          const SizedBox(height: 20),
          const LegalLinksSection(),
        ],
      ),
    );
  }
}
