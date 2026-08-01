import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/lock_service.dart';
import '../../../../../core/services/inactivity_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_controller.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _lockService = LockService();
  bool _biometricEnabled = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _lockService.isEnabled().then((v) {
      if (mounted) setState(() => _biometricEnabled = v);
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _biometricBusy = true);
    try {
      if (value) {
        final canCheck = await _lockService.canUseBiometrics();
        if (!canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Aucune empreinte/visage enregistré sur cet appareil, ou biométrie non supportée.")),
            );
          }
          return;
        }
        final ok = await _lockService.authenticate(reason: 'Confirmez pour activer le verrouillage biométrique');
        if (!ok) return;
      }
      await _lockService.setEnabled(value);
      if (mounted) setState(() => _biometricEnabled = value);
      if (value) {
        InactivityService.instance.start();
      } else {
        InactivityService.instance.stop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Verrouillage biométrique activé.' : 'Verrouillage biométrique désactivé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur biométrie : $e')));
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _contactUs() async {
    final uri = Uri(scheme: 'mailto', path: 'support@livra.app', query: 'subject=Support Livra');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune application email trouvée. Écris-nous à support@livra.app')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), actions: [notificationBellAction(context)]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(user?.email?.substring(0, 1).toUpperCase() ?? '?', style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 12),
          Text(user?.email ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('Portefeuille'), onTap: () => context.push('/wallet')),
          ListTile(leading: const Icon(Icons.history), title: const Text('Historique'), onTap: () => context.push('/client/history')),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('DEVENIR PARTENAIRE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6)),
          ),
          ListTile(
            leading: const Icon(Icons.two_wheeler_outlined),
            title: const Text('Devenir livreur / chauffeur'),
            subtitle: const Text('Livraison colis, moto-taxi, voiture-taxi', style: TextStyle(fontSize: 12)),
            onTap: () => context.push('/apply-driver'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Devenir vendeur'),
            subtitle: const Text('Vendre sur Livra (restaurant, boutique)', style: TextStyle(fontSize: 12)),
            onTap: () => context.push('/apply-vendor'),
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.fingerprint)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verrouillage biométrique', style: TextStyle(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        "Exige une authentification locale à l'ouverture",
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _biometricBusy
                    ? const SizedBox(width: 40, height: 24, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                    : Switch(value: _biometricEnabled, activeColor: AppColors.gold, onChanged: _toggleBiometric),
              ],
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Mode clair'),
              value: mode == ThemeMode.light,
              activeColor: AppColors.gold,
              onChanged: (_) => ThemeController.instance.toggle(),
            ),
          ),
          const Divider(height: 24),
          ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('Nous contacter'), onTap: _contactUs),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.danger),
            title: Text('Déconnexion', style: TextStyle(color: AppColors.danger)),
            onTap: () => AuthService().logout(),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}
