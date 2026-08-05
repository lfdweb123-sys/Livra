import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/remote_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/phone_number_field.dart';

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
  static const _countries = [
    'Bénin',
    'Togo',
    "Côte d'Ivoire",
    'Congo Brazzaville',
    'Sénégal',
    'Burkina Faso',
    'Mali'
  ];

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = switch (_intent) {
        _Intent.client => 'client',
        _Intent.resto || _Intent.shop => 'vendor',
        _Intent.livreurColis ||
        _Intent.taxiMoto ||
        _Intent.chauffeurVoiture =>
          'driver',
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

  InputDecoration _decoration(
      {required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: AppColors.surfaceElevated,
                  child: const Center(child: AppLogo(size: 72, full: true)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Créer un compte',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Ça prend moins d'une minute",
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                decoration: _decoration(
                    hint: 'Nom complet', icon: Icons.person_outline_rounded),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _country,
                decoration: _decoration(hint: '', icon: Icons.public_rounded),
                dropdownColor: AppColors.surfaceElevated,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _country = v ?? _country),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cityCtrl,
                decoration: _decoration(
                    hint: 'Ville', icon: Icons.location_city_rounded),
              ),
              const SizedBox(height: 14),
              PhoneNumberField(
                  initialCountry: _country,
                  onChanged: (v) => _phoneCtrl.text = v),
              const SizedBox(height: 14),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email
                      ],
                      decoration: _decoration(
                          hint: 'Email', icon: Icons.mail_outline_rounded),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      decoration: _decoration(
                        hint: 'Mot de passe (6 caractères min.)',
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Vous êtes',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<_Intent>(
                value: _intent,
                isExpanded: true,
                decoration: _decoration(hint: '', icon: Icons.badge_outlined),
                dropdownColor: AppColors.surfaceElevated,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
                items: _Intent.values
                    .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text(_intentLabels[i]!,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _intent = v ?? _intent),
              ),
              if (_intent != _Intent.client) ...[
                const SizedBox(height: 8),
                Text(
                  "Une vérification d'identité (documents) vous sera demandée juste après, avant de pouvoir démarrer.",
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                  label: "S'inscrire", onPressed: _submit, loading: _loading),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4),
                  children: [
                    const TextSpan(
                        text: "En vous inscrivant, vous acceptez nos "),
                    TextSpan(
                      text: "Conditions d'utilisation",
                      style: TextStyle(
                          color: AppColors.gold, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: " et notre "),
                    TextSpan(
                      text: "Politique de confidentialité",
                      style: TextStyle(
                          color: AppColors.gold, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
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
