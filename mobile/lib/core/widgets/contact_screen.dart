import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';

/// Appel/WhatsApp — ouvre l'app téléphone ou WhatsApp du système avec le
/// numéro pré-rempli. Ce n'est PAS un vrai appel intégré (pas de VoIP dans
/// l'app) : construire un vrai système d'appel sans jamais quitter l'app
/// demanderait une infrastructure WebRTC complète (serveur de signalisation,
/// etc.), un chantier à part entière. Ceci reste la façon la plus fiable et
/// rapide de mettre client et livreur/vendeur en contact aujourd'hui — et
/// les deux parties utilisent bien leur propre forfait/data, pas celui de Livra.
class ContactScreen extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final String role; // "votre livreur", "votre client", etc.

  const ContactScreen({super.key, required this.name, required this.phoneNumber, required this.role});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(role, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.call_rounded,
                      label: 'Appeler',
                      color: AppColors.success,
                      onTap: _call,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: _whatsapp,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Vous restez sur votre propre forfait ou connexion internet — Livra ne facture pas les appels.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet rapide pour choisir "Appeler" / "WhatsApp" sans changer
/// d'écran (utilisé depuis le suivi de commande/course).
Future<void> showQuickContactSheet(BuildContext context, {required String name, required String phoneNumber}) {
  return showAppBottomSheet(
    context,
    title: 'Contacter $name',
    child: Row(
      children: [
        Expanded(
          child: ListTile(
            leading: Icon(Icons.call_rounded, color: AppColors.success),
            title: const Text('Appeler'),
            onTap: () async {
              Navigator.pop(context);
              final uri = Uri(scheme: 'tel', path: phoneNumber);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ),
      ],
    ),
  );
}
