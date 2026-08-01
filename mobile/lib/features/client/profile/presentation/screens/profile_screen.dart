import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/lock_service.dart';
import '../../../../../core/services/inactivity_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_controller.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/services/app_content_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _lockService = LockService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _busy = false;
  String _supportEmail = 'support@livra.app';
  String _supportPhone = '';
  String _supportWhatsapp = '';

  @override
  void initState() {
    super.initState();
    _loadLockState();
    _loadSupportContacts();
  }

  Future<void> _loadSupportContacts() async {
    final config = await AppContentService().fetch();
    if (mounted) {
      setState(() {
        _supportEmail = config.supportEmail;
        _supportPhone = config.supportPhone;
        _supportWhatsapp = config.supportWhatsapp;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final enabled = await _lockService.isLockEnabled();
    final available = await _lockService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricAvailable = available;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      if (!_biometricAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucune empreinte enregistrée sur cet appareil.")),
        );
        return;
      }
      setState(() => _busy = true);
      try {
        final ok = await _lockService.authenticateBiometric(reason: "Confirmez pour activer l'empreinte digitale");
        if (!ok) return;
        await _lockService.setLockEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
        InactivityService.instance.start();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      await _lockService.setLockEnabled(false);
      InactivityService.instance.stop();
      if (mounted) setState(() => _biometricEnabled = false);
    }
  }

  /// mailto: est prioritaire — Android le route vers l'app mail installée
  /// (Gmail si c'est l'app par défaut, ce qui est le cas sur la quasi-
  /// totalité des téléphones Android). Le lien web gmail.com n'est qu'un
  /// tout dernier recours : il ouvre Chrome, pas l'app Gmail, donc on
  /// l'évite sauf si aucune app mail n'est installée du tout.
  Future<void> _contactUs() async {
    final mailto = Uri(scheme: 'mailto', path: _supportEmail, query: 'subject=Support Livra');
    try {
      final launched = await launchUrl(mailto);
      if (launched) return;
    } catch (_) {}

    final gmailWeb = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1&to=$_supportEmail&su=${Uri.encodeComponent("Support Livra")}',
    );
    try {
      await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Écrivez-nous à $_supportEmail')),
        );
      }
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: _supportEmail));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copié.')));
  }

  Widget _smallLink(BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(6),
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
    );
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              user?.email ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: _busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fingerprint),
            title: const Text('Empreinte digitale'),
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
            subtitle: Text(_supportEmail, style: const TextStyle(fontSize: 12)),
            onTap: _contactUs,
            trailing: IconButton(icon: const Icon(Icons.copy_rounded, size: 18), onPressed: _copyEmail),
          ),
          if (_supportPhone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Nous appeler'),
              subtitle: Text(_supportPhone, style: const TextStyle(fontSize: 12)),
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: _supportPhone);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          if (_supportWhatsapp.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat_rounded),
              title: const Text('WhatsApp'),
              subtitle: Text('+$_supportWhatsapp', style: const TextStyle(fontSize: 12)),
              onTap: () async {
                final uri = Uri.parse('https://wa.me/$_supportWhatsapp');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
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
}
