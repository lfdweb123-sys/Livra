import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/debounced_button.dart';
import '../../../../core/services/remote_logger.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Renseignez une adresse email valide.');
      return;
    }
    setState(() => _error = null);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = RemoteLogger.readableAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(size: 64)),
              const SizedBox(height: 28),
              if (_sent) ...[
                Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 48),
                const SizedBox(height: 16),
                const Text('Email envoyé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Si un compte existe avec l\'adresse ${_emailCtrl.text.trim()}, vous recevrez un lien pour réinitialiser votre mot de passe. Vérifiez aussi vos spams.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour à la connexion'),
                ),
              ] else ...[
                const Text('Réinitialiser votre mot de passe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Renseignez l\'adresse email de votre compte Livra — vous recevrez un lien pour choisir un nouveau mot de passe.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'votre@email.com'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                DebouncedButton(label: 'Envoyer le lien', onPressed: _submit),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
