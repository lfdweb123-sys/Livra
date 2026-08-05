import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_store.dart';
import 'credentials_store.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerClient({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String country,
    required String city,
    String role = 'client',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'role': role,
      'name': name,
      'phone': phone,
      'email': email,
      'country': country,
      'city': city,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Une inscription est toujours une action manuelle de l'utilisateur —
    // on démarre donc le compteur de session de 30 jours ici aussi.
    await SessionStore().recordLogin();
    return cred;
  }

  /// À n'appeler QUE depuis une soumission manuelle du formulaire de
  /// connexion (jamais automatiquement au démarrage de l'app) — voir
  /// login_screen.dart. Démarre le compteur de session de 30 jours.
  Future<UserCredential> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await SessionStore().recordLogin();
    return cred;
  }

  /// Déconnexion complète: efface la session Firebase, le compteur des
  /// 30 jours, ET les identifiants "Se souvenir de moi" — sinon l'écran de
  /// connexion les retrouve et rouvre une session dans la foulée, ce qui
  /// rendait la déconnexion inopérante.
  Future<void> logout() async {
    await _auth.signOut();
    await SessionStore().clear();
    await CredentialsStore().clear();
  }

  /// Vérifie la limite de session de 30 jours. Si dépassée, force une
  /// déconnexion complète (voir logout()) — appelé une fois au démarrage.
  Future<void> enforceSessionExpiry() async {
    if (_auth.currentUser == null) return;
    if (await SessionStore().isExpired()) {
      await logout();
    }
  }

  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }
}
