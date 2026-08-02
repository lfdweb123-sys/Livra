import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/remote_logger.dart';
import '../../../../core/services/credentials_store.dart';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/phone_number_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _credentialsStore = CredentialsStore();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _usePhone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await _credentialsStore.read();
    if (saved != null && mounted) {
      setState(() {
        _emailCtrl.text = saved.email;
        _passwordCtrl.text = saved.password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _submit() async {
    final identifier = _usePhone ? _phoneCtrl.text.trim() : _emailCtrl.text.trim();
    if (identifier.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = _usePhone ? 'Renseignez votre numéro et votre mot de passe.' : 'Renseignez votre email et votre mot de passe.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      String email;
      if (_usePhone) {
        // Le téléphone n'est pas un identifiant Firebase Auth ici — on
        // retrouve d'abord l'email associé, puis la connexion se fait
        // normalement avec ce mot de passe (jamais transmis à cette étape).
        final res = await ApiClient.instance.post('/api/auth/lookup-phone', data: {'phone': identifier});
        email = res['email'];
      } else {
        email = identifier;
      }
      await _authService.login(email: email, password: _passwordCtrl.text);
      if (_rememberMe) {
        await _credentialsStore.save(email, _passwordCtrl.text);
      } else {
        await _credentialsStore.clear();
      }
      // Signale à Android que la saisie est terminée avec succès — c'est ce
      // qui déclenche le prompt système "Enregistrer le mot de passe ?".
      TextInput.finishAutofillContext();
      // La redirection vers /client/home, /driver/home ou /vendor/dashboard
      // se fait automatiquement via RoleGate + AppRouter.redirect.
    } catch (e, stack) {
      RemoteLogger.log(context: 'login', error: e, stack: stack);
      final msg = e.toString().contains('no_account_for_this_phone')
          ? 'Aucun compte associé à ce numéro.'
          : RemoteLogger.readableAuthError(e);
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(child: AppLogo(size: 130, full: true)),
              const SizedBox(height: 20),
              const Text('Content de vous revoir', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Connectez-vous pour continuer',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Email'), icon: Icon(Icons.mail_outline_rounded, size: 16)),
                    ButtonSegment(value: true, label: Text('Téléphone'), icon: Icon(Icons.phone_outlined, size: 16)),
                  ],
                  selected: {_usePhone},
                  onSelectionChanged: (s) => setState(() => _usePhone = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? AppColors.gold : AppColors.surfaceElevated,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AutofillGroup(
                child: Column(
                  children: [
                    if (_usePhone)
                      PhoneNumberField(onChanged: (v) => _phoneCtrl.text = v)
                    else
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Mot de passe',
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
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.gold,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Se souvenir de moi', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
              PrimaryButton(label: 'Se connecter', onPressed: _submit, loading: _loading),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/register'),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      children: [
                        TextSpan(text: "Pas encore de compte ? "),
                        TextSpan(text: "S'inscrire", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "En vous connectant, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité.",
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
