import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';

class VendorDashboardScreen extends StatefulWidget {
  VendorDashboardScreen({super.key});
  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  Map<String, dynamic>? _vendor;
  String? _vendorId;
  bool _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).snapshots().listen((snap) {
      if (snap.docs.isEmpty) {
        // Rôle "vendor" mais candidature jamais terminée (app fermée en
        // cours de route) — sans ça, l'écran restait bloqué en chargement
        // indéfiniment, jamais d'erreur, jamais de sortie possible.
        if (_checkedOnce && mounted) context.go('/apply-vendor');
        setState(() => _checkedOnce = true);
        return;
      }
      setState(() {
        _vendorId = snap.docs.first.id;
        _vendor = snap.docs.first.data();
      });
    });
  }

  Future<void> _toggleOpen(bool value) async {
    if (_vendorId == null) return;
    await ApiClient.instance.patch('/api/vendors/$_vendorId', data: {'isOpen': value});
  }

  @override
  Widget build(BuildContext context) {
    if (_vendor == null) return Scaffold(body: SkeletonCardList());
    if (_vendor!['status'] != 'active') {
      return Scaffold(
        appBar: AppBar(title: Text('Espace vendeur'), actions: [notificationBellAction(context)]),
        body: EmptyState(
          icon: Icons.hourglass_top_rounded,
          message: _vendor!['status'] == 'pending'
              ? 'Votre candidature est en cours de validation par notre équipe.'
              : 'Votre boutique est actuellement ${_vendor!['status']}.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_vendor!['businessName'] ?? 'Espace vendeur'),
        actions: [IconButton(icon: Icon(Icons.account_balance_wallet_outlined), onPressed: () => context.push('/wallet')), notificationBellAction(context)],
      ),
      body: swipeableTab(context: context, currentIndex: 0, child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Expanded(child: Text(_vendor!['isOpen'] == true ? 'Boutique ouverte' : 'Boutique fermée', style: TextStyle(fontWeight: FontWeight.w600))),
                Switch(value: _vendor!['isOpen'] == true, activeColor: AppColors.gold, onChanged: _toggleOpen),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _tile(context, 'Catalogue', Icons.restaurant_menu, '/vendor/catalog')),
              SizedBox(width: 12),
              Expanded(child: _tile(context, 'Commandes', Icons.receipt_long, '/vendor/orders')),
            ],
          ),
          SizedBox(height: 12),
          _tile(context, 'Statistiques', Icons.bar_chart_rounded, '/vendor/stats'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tile(context, 'Publicité', Icons.campaign_outlined, '/vendor/ads')),
              const SizedBox(width: 12),
              Expanded(child: _tile(context, 'Mon profil', Icons.storefront_outlined, '/vendor/profile')),
            ],
          ),
        ],
      ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _tile(BuildContext context, String label, IconData icon, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 28),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
