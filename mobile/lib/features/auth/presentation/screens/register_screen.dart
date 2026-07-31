import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

/// Inscription = toujours "client" au départ. Devenir livreur/vendeur se
/// fait ensuite via une candidature séparée (apply-driver / apply-vendor),
/// validée par l'admin.
class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.registerClient(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
    } catch (e) {
      setState(() => _error = "Impossible de créer le compte. Vérifiez vos informations.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Créer un compte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              SizedBox(height: 24),
              TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Nom complet')),
              SizedBox(height: 12),
              TextField(controller: _phoneCtrl, decoration: InputDecoration(hintText: 'Téléphone (+229...)'), keyboardType: TextInputType.phone),
              SizedBox(height: 12),
              TextField(controller: _emailCtrl, decoration: InputDecoration(hintText: 'Email'), keyboardType: TextInputType.emailAddress),
              SizedBox(height: 12),
              TextField(controller: _passwordCtrl, decoration: InputDecoration(hintText: 'Mot de passe'), obscureText: true),
              if (_error != null) ...[
                SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.danger)),
              ],
              SizedBox(height: 24),
              PrimaryButton(label: "S'inscrire", onPressed: _submit, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
