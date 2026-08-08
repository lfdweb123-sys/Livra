import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/countries.dart';
import '../theme/app_colors.dart';

/// Section "Pays" du profil — change ce que l'utilisateur voit sur toute
/// l'application (boutiques, livreurs, produits...), voir le filtrage par
/// pays côté backend. Écrit directement sur users/{uid}.country.
class CountrySelectorTile extends StatefulWidget {
  const CountrySelectorTile({super.key});
  @override
  State<CountrySelectorTile> createState() => _CountrySelectorTileState();
}

class _CountrySelectorTileState extends State<CountrySelectorTile> {
  String? _country;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() => _country = doc.data()?['country']);
  }

  Future<void> _change() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Changer de pays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Vous ne verrez plus que les boutiques, livreurs et produits de ce pays.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ...kAvailableCountries.map((c) => ListTile(
                  title: Text(c),
                  trailing: c == _country ? Icon(Icons.check, color: AppColors.gold) : null,
                  onTap: () => Navigator.pop(context, c),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && selected != _country) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'country': selected});
      if (mounted) {
        setState(() => _country = selected);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pays changé pour $selected.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.public_outlined),
        title: const Text('Pays'),
        subtitle: Text(_country ?? '—', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _change,
      ),
    );
  }
}
