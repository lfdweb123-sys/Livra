import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/lock_service.dart';
import '../../../../../core/services/inactivity_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _lockService = LockService();
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _lockService.isEnabled().then((v) => setState(() => _biometricEnabled = v));
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final canCheck = await _lockService.canUseBiometrics();
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biométrie non disponible sur cet appareil.')),
          );
        }
        return;
      }
      final ok = await _lockService.authenticate(reason: 'Confirmez pour activer le verrouillage biométrique');
      if (!ok) return;
    }
    await _lockService.setEnabled(value);
    setState(() => _biometricEnabled = value);
    if (value) {
      InactivityService.instance.start();
    } else {
      InactivityService.instance.stop();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Verrouillage biométrique activé — actif au prochain démarrage.' : 'Verrouillage biométrique désactivé.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('Profil')),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(user?.email?.substring(0, 1).toUpperCase() ?? '?', style: TextStyle(fontSize: 28)),
          ),
          SizedBox(height: 12),
          Text(user?.email ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 24),
          ListTile(leading: Icon(Icons.account_balance_wallet_outlined), title: Text('Portefeuille'), onTap: () => context.push('/wallet')),
          ListTile(leading: Icon(Icons.history), title: Text('Historique'), onTap: () => context.push('/client/history')),
          ListTile(leading: Icon(Icons.two_wheeler_outlined), title: Text('Devenir livreur / chauffeur'), onTap: () => context.push('/apply-driver')),
          ListTile(leading: Icon(Icons.storefront_outlined), title: Text('Devenir vendeur'), onTap: () => context.push('/apply-vendor')),
          SwitchListTile(
            secondary: Icon(Icons.fingerprint),
            title: Text('Verrouillage biométrique'),
            subtitle: Text('Exige une authentification locale à chaque ouverture', style: TextStyle(fontSize: 12)),
            value: _biometricEnabled,
            activeColor: AppColors.gold,
            onChanged: _toggleBiometric,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) => SwitchListTile(
              secondary: Icon(Icons.dark_mode_outlined),
              title: Text('Mode clair'),
              value: mode == ThemeMode.light,
              activeColor: AppColors.gold,
              onChanged: (_) => ThemeController.instance.toggle(),
            ),
          ),
          Divider(color: AppColors.divider, height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.danger),
            title: Text('Déconnexion', style: TextStyle(color: AppColors.danger)),
            onTap: () => AuthService().logout(),
          ),
        ],
      ),
    );
  }
}
