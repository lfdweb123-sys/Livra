import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/remote_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/phone_number_field.dart';

/// Inscription = toujours "client" en base (role='client'), mais on demande
/// directement l'intention (client simple, ou candidat vendeur/livreur) pour
/// enchaîner sur la vérification d'identité correspondante juste après —
/// sauf pour un client, qui va directement à l'accueil.
enum _Intent { client, resto, shop, livreurColis, taxiMoto, chauffeurVoiture }

const _intentLabels = {
  _Intent.client: 'Client — je commande sur Livra',
  _Intent.resto: 'Restaurant — je vends de la nourriture',
  _Intent.shop: 'Boutique — je vends des produits',
  _Intent.livreurColis: 'Livreur — je livre des colis',
  _Intent.taxiMoto: 'Taxi-moto — je transporte des clients',
  _Intent.chauffeurVoiture: 'Chauffeur voiture — je transporte des clients',
};

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _countries = ['Bénin', 'Togo', "Côte d'Ivoire", 'Congo Brazzaville', 'Sénégal', 'Burkina Faso', 'Mali'];

  final _authService = AuthService();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _country = _countries.first;
  _Intent _intent = _Intent.client;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Merci de remplir tous les champs.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final role = switch (_intent) {
        _Intent.client => 'client',
        _Intent.resto || _Intent.shop => 'vendor',
        _Intent.livreurColis || _Intent.taxiMoto || _Intent.chauffeurVoiture => 'driver',
      };
      await _authService.registerClient(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        country: _country,
        city: _cityCtrl.text.trim(),
        role: role,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      // Client simple -> accueil directement (redirection automatique).
      // Toute autre intention -> vérification d'identité obligatoire avant
      // l'accueil, préremplie selon le choix fait ici.
      switch (_intent) {
        case _Intent.client:
          break;
        case _Intent.resto:
          context.go('/apply-vendor', extra: {'category': 'resto'});
          break;
        case _Intent.shop:
          context.go('/apply-vendor', extra: {'category': 'shop'});
          break;
        case _Intent.livreurColis:
          context.go('/apply-driver', extra: {'vehicleType': 'coursier'});
          break;
        case _Intent.taxiMoto:
          context.go('/apply-driver', extra: {'vehicleType': 'moto'});
          break;
        case _Intent.chauffeurVoiture:
          context.go('/apply-driver', extra: {'vehicleType': 'voiture'});
          break;
      }
    } catch (e, stack) {
      RemoteLogger.log(context: 'register', error: e, stack: stack);
      setState(() => _error = RemoteLogger.readableAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 64, full: true)),
              const SizedBox(height: 16),
              const Text('Créer un compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Ça prend moins d\'une minute',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Nom complet', prefixIcon: Icon(Icons.person_outline_rounded)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _country,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.public_rounded)),
                dropdownColor: AppColors.surfaceElevated,
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _country = v ?? _country),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtrl,
                decoration: const InputDecoration(hintText: 'Ville', prefixIcon: Icon(Icons.location_city_rounded)),
              ),
              const SizedBox(height: 12),
              PhoneNumberField(initialCountry: _country, onChanged: (v) => _phoneCtrl.text = v),
              const SizedBox(height: 12),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Mot de passe (6 caractères min.)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Vous êtes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<_Intent>(
                value: _intent,
                isExpanded: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
                dropdownColor: AppColors.surfaceElevated,
                items: _Intent.values.map((i) => DropdownMenuItem(value: i, child: Text(_intentLabels[i]!, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _intent = v ?? _intent),
              ),
              if (_intent != _Intent.client) ...[
                const SizedBox(height: 6),
                Text(
                  "Une vérification d'identité (documents) vous sera demandée juste après, avant de pouvoir démarrer.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: "S'inscrire", onPressed: _submit, loading: _loading),
              const SizedBox(height: 12),
              Text(
                "En vous inscrivant, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité.",
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
