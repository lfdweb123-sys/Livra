import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/debounced_button.dart';
import '../../../../../core/widgets/legal_links_section.dart';
import '../../../../../core/widgets/country_selector_tile.dart';
import '../../../../../core/widgets/phone_number_field.dart';
import '../../../../../core/services/friendly_error.dart';

/// Modifier ses informations personnelles — accessible depuis Profil.
/// Contient aussi les politiques (CGU, confidentialité...), déplacées
/// depuis la page Profil elle-même qui ne les affiche plus directement.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _phone = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (mounted) {
      setState(() {
        _nameCtrl.text = data?['name'] ?? '';
        _cityCtrl.text = data?['city'] ?? '';
        _phone = data?['phone'] ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom ne peut pas être vide.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        if (_phone.isNotEmpty) 'phone': _phone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations mises à jour.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes informations')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('Nom complet', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Votre nom')),
                const SizedBox(height: 16),
                Text('Téléphone', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                PhoneNumberField(initialValue: _phone, onChanged: (v) => _phone = v),
                const SizedBox(height: 16),
                Text('Ville', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: _cityCtrl, decoration: const InputDecoration(hintText: 'Votre ville')),
                const SizedBox(height: 16),
                Text('Email', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(child: Text(user?.email ?? '—', style: TextStyle(color: AppColors.textSecondary))),
                      Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Pour changer d'email, contactez le support depuis votre profil.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 24),
                DebouncedButton(label: 'Enregistrer', onPressed: _save),
                const SizedBox(height: 28),
                const CountrySelectorTile(),
                const SizedBox(height: 28),
                const LegalLinksSection(),
              ],
            ),
    );
  }
}
