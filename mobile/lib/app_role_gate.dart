import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/models/user_model.dart';
import 'core/services/auth_service.dart';
import 'core/services/twilio_call_service.dart';
import 'core/services/notifications/fcm_service.dart';
import 'core/routing/app_router.dart';

/// Écoute l'auth + le doc users/{uid} pour maintenir AppRouter.currentRole
/// à jour, et déclenche une réévaluation du routing à chaque changement.
///
/// Le champ `role` du document utilisateur reste "client" pour tout le
/// monde (postuler ne le modifie jamais) — donc un vendeur/livreur APPROUVÉ
/// n'atterrissait jamais sur son tableau de bord après connexion, faute
/// d'un signal pour le distinguer d'un simple client. On vérifie donc aussi
/// l'existence d'un profil vendeur/livreur actif, prioritaire sur "client".
class RoleGate extends StatefulWidget {
  final Widget child;
  RoleGate({super.key, required this.child});
  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final _authService = AuthService();
  UserRole? _baseRole;
  bool _hasActiveVendor = false;
  bool _hasActiveDriver = false;

  // IMPORTANT (bug corrigé): ces abonnements Firestore n'étaient auparavant
  // JAMAIS annulés — à chaque connexion, de nouveaux listeners étaient
  // créés sans jamais fermer ceux du compte précédent. Si un utilisateur
  // se déconnectait puis se reconnectait avec un AUTRE compte dans la même
  // session d'app (ex: testé "Livreur" puis "Client"), les anciens
  // listeners du compte précédent continuaient de tourner et pouvaient
  // écraser AppRouter.currentRole avec les données PÉRIMÉES de l'ancien
  // compte à tout moment — c'est exactement pourquoi un client "simple"
  // pouvait se retrouver avec "vérification d'identité requise" (état
  // d'un ancien compte livreur/vendeur testé sur le même appareil), et
  // pourquoi vider le cache de l'app "réglait" le problème (ça tuait les
  // listeners fantômes).
  StreamSubscription? _userDocSub;
  StreamSubscription? _vendorSub;
  StreamSubscription? _driverSub;

  @override
  void initState() {
    super.initState();
    // Déconnexion automatique après 30 jours de session (voir
    // SessionStore) — vérifié une fois au démarrage, avant de laisser
    // authStateChanges() router l'utilisateur vers son tableau de bord.
    _authService.enforceSessionExpiry();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      // Ferme SYSTÉMATIQUEMENT tous les abonnements du compte précédent
      // avant d'en ouvrir de nouveaux (ou de repartir à zéro si
      // déconnecté) — plus aucun listener fantôme possible.
      _userDocSub?.cancel();
      _vendorSub?.cancel();
      _driverSub?.cancel();
      _baseRole = null;
      _hasActiveVendor = false;
      _hasActiveDriver = false;

      if (user == null) {
        AppRouter.currentRole = null;
        AppRouter.refresh();
        return;
      }
      _userDocSub = _authService.watchUserDoc(user.uid).listen((snap) {
        if (snap.exists) {
          _baseRole = roleFromString(snap.data()?['role']);
          _applyEffectiveRole();
        }
      });
      _watchActiveVendorOrDriver(user.uid);
      // IMPORTANT: réenregistré ici (pas seulement une fois au tout
      // premier lancement dans main.dart) car FirebaseAuth.currentUser
      // n'est souvent pas encore résolu à ce moment-là — le token FCM
      // n'était alors jamais sauvegardé (uid == null), ce qui causait
      // 'no_token' pour de nombreux comptes malgré une session active.
      // Ici, l'utilisateur est garanti authentifié.
      FcmService().initAndSaveToken().catchError((_) {});
      // best-effort — ne bloque jamais le flux de connexion si Twilio échoue
      TwilioCallService.instance.registerForIncomingCalls().catchError((_) {});
    });
  }

  void _watchActiveVendorOrDriver(String uid) {
    _vendorSub = FirebaseFirestore.instance
        .collection('vendors')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      _hasActiveVendor = snap.docs.isNotEmpty;
      _applyEffectiveRole();
    });
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      _hasActiveDriver = snap.docs.isNotEmpty;
      _applyEffectiveRole();
    });
  }

  void _applyEffectiveRole() {
    if (_baseRole == null) return;
    if (_baseRole == UserRole.admin) {
      AppRouter.currentRole = UserRole.admin;
    } else if (_hasActiveVendor) {
      AppRouter.currentRole = UserRole.vendor;
    } else if (_hasActiveDriver) {
      AppRouter.currentRole = UserRole.driver;
    } else {
      AppRouter.currentRole = _baseRole;
    }
    if (mounted) AppRouter.refresh();
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _vendorSub?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
