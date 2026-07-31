import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      // La redirection vers /client/home, /driver/home ou /vendor/dashboard
      // se fait automatiquement via RoleGate + AppRouter.redirect.
    } catch (e) {
      setState(() => _error = 'Email ou mot de passe incorrect.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32),
              Text('Livra', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gold)),
              SizedBox(height: 8),
              Text('Content de vous revoir', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 32),
              TextField(controller: _emailCtrl, decoration: InputDecoration(hintText: 'Email'), keyboardType: TextInputType.emailAddress),
              SizedBox(height: 12),
              TextField(controller: _passwordCtrl, decoration: InputDecoration(hintText: 'Mot de passe'), obscureText: true),
              if (_error != null) ...[
                SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.danger)),
              ],
              SizedBox(height: 24),
              PrimaryButton(label: 'Se connecter', onPressed: _submit, loading: _loading),
              SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/register'),
                  child: Text("Pas encore de compte ? S'inscrire", style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
