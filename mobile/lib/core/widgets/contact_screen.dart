import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/twilio_call_service.dart';
import '../theme/app_colors.dart';
import 'in_app_call_screen.dart';

/// Appel/WhatsApp/Appel Livra — le bouton "Appel Livra" utilise Twilio Voice
/// (vraie VoIP intégrée, chacun sur sa propre connexion internet, sans
/// jamais quitter l'app). "Appeler" et "WhatsApp" restent en repli fiable
/// si l'appel Livra échoue (réseau instable, etc.).
class ContactScreen extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final String role; // "votre livreur", "votre client", etc.
  final String? calleeUid; // requis pour l'appel Livra (VoIP)

  const ContactScreen({super.key, required this.name, required this.phoneNumber, required this.role, this.calleeUid});

  Future<void> _callLivra(BuildContext context) async {
    if (calleeUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appel Livra indisponible pour ce contact.')));
      return;
    }
    try {
      await TwilioCallService.instance.call(toUid: calleeUid!, displayName: name);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => InAppCallScreen(name: name)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appel Livra indisponible : $e. Essayez "Appeler".')));
      }
    }
  }

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
              const SizedBox(height: 28),
              if (calleeUid != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _callLivra(context),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                    label: const Text('Appel Livra (gratuit, via internet)'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: AppColors.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('ou', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Container(height: 1, color: AppColors.divider)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: _actionButton(icon: Icons.call_rounded, label: 'Appeler', color: AppColors.success, onTap: _call),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _actionButton(icon: Icons.chat_rounded, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: _whatsapp),
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
