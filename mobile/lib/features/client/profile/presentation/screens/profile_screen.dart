import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/services/auth_service.dart';
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
  String _supportEmail = 'support@livra.app';
  String _supportPhone = '';
  String _supportWhatsapp = '';
  // null = pas encore candidat, sinon 'pending' | 'active' | 'suspended' | 'rejected'
  String? _vendorStatus;
  String? _driverStatus;

  @override
  void initState() {
    super.initState();
    _loadSupportContacts();
    _loadApplicationStatus();
  }

  Future<void> _loadApplicationStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final vendorSnap = await FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).get();
    final driverSnap = await FirebaseFirestore.instance.collection('drivers').where('ownerId', isEqualTo: uid).limit(1).get();
    if (mounted) {
      setState(() {
        _vendorStatus = vendorSnap.docs.isNotEmpty ? vendorSnap.docs.first.data()['status'] : null;
        _driverStatus = driverSnap.docs.isNotEmpty ? driverSnap.docs.first.data()['status'] : null;
      });
    }
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

  static const _statusLabelsFr = {
    'pending': 'Candidature en cours de vérification',
    'active': 'Déjà activé',
    'suspended': 'Compte suspendu',
    'rejected': 'Candidature refusée — retenter',
  };

  Widget _partnerButton(BuildContext context, String label, IconData icon, String route, String? status, String dashboardRoute, {bool blockedByOtherRole = false}) {
    final disabled = status == 'pending' || status == 'suspended' || blockedByOtherRole;
    final goToDashboard = status == 'active';
    final statusText = blockedByOtherRole && status == null
        ? 'Indisponible — un compte ne peut être que vendeur OU livreur'
        : (status != null ? (_statusLabelsFr[status] ?? status) : null);
    return SizedBox(
      width: double.infinity,
      height: statusText != null ? 60 : 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: disabled
              ? null
              : LinearGradient(colors: [AppColors.goldSoft, AppColors.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: disabled ? AppColors.surfaceElevated : null,
          boxShadow: disabled ? null : [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: disabled ? null : () => context.push(goToDashboard ? dashboardRoute : route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(goToDashboard ? Icons.dashboard_rounded : icon, size: 18, color: disabled ? AppColors.textSecondary : Colors.black),
                    const SizedBox(width: 8),
                    Text(goToDashboard ? 'Aller à mon espace' : label, style: TextStyle(color: disabled ? AppColors.textSecondary : Colors.black, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ],
                ),
                if (statusText != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      statusText,
                      style: TextStyle(color: disabled ? AppColors.textSecondary : Colors.black87, fontSize: 10.5),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), actions: [notificationBellAction(context)]),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSupportContacts();
          await _loadApplicationStatus();
        },
        color: AppColors.gold,
        child: ListView(
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
          const SizedBox(height: 8),
          _partnerButton(
            context, 'Devenir livreur / chauffeur', Icons.two_wheeler_rounded, '/apply-driver', _driverStatus, '/driver/home',
            blockedByOtherRole: _vendorStatus != null && _vendorStatus != 'rejected',
          ),
          const SizedBox(height: 12),
          _partnerButton(
            context, 'Devenir vendeur', Icons.storefront_rounded, '/apply-vendor', _vendorStatus, '/vendor/dashboard',
            blockedByOtherRole: _driverStatus != null && _driverStatus != 'rejected',
          ),
          const Divider(height: 28),
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
              subtitle: Text('+${_supportWhatsapp.replaceAll('+', '')}', style: const TextStyle(fontSize: 12)),
              onTap: () async {
                final digits = _supportWhatsapp.replaceAll('+', '').trim();
                final uri = Uri.parse('https://wa.me/$digits');
                // canLaunchUrl donne souvent un faux négatif sur les liens
                // https (dépend du PackageManager du téléphone) — on tente
                // directement le launchUrl et on ne prévient l'utilisateur
                // que si ça échoue réellement, au lieu de bloquer le bouton
                // en amont sur un simple "je ne sais pas".
                try {
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Impossible d'ouvrir WhatsApp. Est-il installé ?")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur WhatsApp : $e')));
                  }
                }
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
