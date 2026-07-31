import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/models/user_model.dart';
import 'core/services/auth_service.dart';
import 'core/routing/app_router.dart';

/// Écoute l'auth + le doc users/{uid} pour maintenir AppRouter.currentRole
/// à jour, et déclenche une réévaluation du routing à chaque changement.
class RoleGate extends StatefulWidget {
  final Widget child;
  RoleGate({super.key, required this.child});
  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        AppRouter.currentRole = null;
        AppRouter.refresh();
        return;
      }
      _authService.watchUserDoc(user.uid).listen((snap) {
        if (snap.exists) {
          AppRouter.currentRole = roleFromString(snap.data()?['role']);
          AppRouter.refresh();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
