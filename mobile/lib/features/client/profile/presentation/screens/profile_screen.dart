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
import '../../../../../core/widgets/pin_pad.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _lockService = LockService();
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final lock = await _lockService.isLockEnabled();
    final bio = await _lockService.isBiometricEnabled();
    final bioAvailable = await _lockService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _lockEnabled = lock;
        _biometricEnabled = bio;
        _biometricAvailable = bioAvailable;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await _askForNewPin();
      if (pin == null) return;
      await _lockService.setPin(pin);
      if (mounted) {
        setState(() => _lockEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verrouillage activé avec votre code PIN.')),
        );
      }
    } else {
      await _lockService.disableLock();
      if (mounted) {
        setState(() { _lockEnabled = false; _biometricEnabled = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verrouillage désactivé.')));
      }
    }
  }

  /// Demande un nouveau PIN (saisi 2 fois pour confirmation). Retourne le
  /// PIN si confirmé, null si annulé ou si les deux saisies ne correspondent pas.
  Future<String?> _askForNewPin() async {
    String? firstPin;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          bool mismatch = false;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PinPad(
                  title: firstPin == null ? 'Choisissez un code à 4 chiffres' : 'Confirmez votre code',
                  subtitle: mismatch ? 'Les codes ne correspondent pas, recommencez.' : null,
                  showError: mismatch,
                  onComplete: (pin) {
                    if (firstPin == null) {
                      setSheetState(() => firstPin = pin);
                    } else if (pin == firstPin) {
                      Navigator.pop(sheetContext, pin);
                    } else {
                      setSheetState(() { mismatch = true; firstPin = null; });
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
    return result;
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      if (!_biometricAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucune empreinte/visage enregistré sur cet appareil.")),
        );
        return;
      }
      setState(() => _busy = true);
      try {
        final ok = await _lockService.authenticateBiometric(reason: 'Confirmez pour activer la biométrie');
        if (!ok) return;
        await _lockService.setBiometricEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biométrie indisponible : $e')));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      await _lockService.setBiometricEnabled(false);
      if (mounted) setState(() => _biometricEnabled = false);
    }
    if (_biometricEnabled) {
      InactivityService.instance.start();
    }
  }

  /// Ouvre Gmail directement (compose pré-rempli), avec repli sur le
  /// client mail par défaut si Gmail n'est pas disponible.
  Future<void> _contactUs() async {
    final gmailWeb = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1&to=support@livra.app&su=${Uri.encodeComponent("Support Livra")}',
    );
    final mailto = Uri(scheme: 'mailto', path: 'support@livra.app', query: 'subject=Support Livra');
    if (await canLaunchUrl(gmailWeb)) {
      await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écrivez-nous directement à support@livra.app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), actions: [notificationBellAction(context)]),
      body: swipeableTab(context: context, currentIndex: 3, child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(user?.email?.substring(0, 1).toUpperCase() ?? '?', style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 12),
          Text(
            user?.email ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Portefeuille'),
            onTap: () => context.push('/wallet'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historique'),
            onTap: () => context.push('/client/history'),
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'DEVENIR PARTENAIRE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _smallLink(context, 'Devenir livreur / chauffeur', '/apply-driver'),
                _smallLink(context, 'Devenir vendeur', '/apply-vendor'),
              ],
            ),
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'SÉCURITÉ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.lock_outline_rounded),
            title: const Text('Verrouillage de l\'application'),
            subtitle: const Text(
              'Demande un code à l\'ouverture',
              style: TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            value: _lockEnabled,
            activeColor: AppColors.gold,
            onChanged: _toggleLock,
          ),
          if (_lockEnabled)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biométrie en complément du code'),
              subtitle: Text(
                _biometricAvailable ? 'Empreinte ou visage, en plus du code PIN' : 'Non disponible sur cet appareil',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: _biometricEnabled,
              activeColor: AppColors.gold,
              onChanged: _busy ? null : _toggleBiometric,
            ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Mode clair'),
              value: mode == ThemeMode.light,
              activeColor: AppColors.gold,
              onChanged: (_) => ThemeController.instance.toggle(),
            ),
          ),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Nous contacter'),
            onTap: _contactUs,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.danger),
            title: Text('Déconnexion', style: TextStyle(color: AppColors.danger)),
            onTap: () => AuthService().logout(),
          ),
        ],
      ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _smallLink(BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.gold, decoration: TextDecoration.underline),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
