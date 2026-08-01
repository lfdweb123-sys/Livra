import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';

/// Envoie les erreurs importantes (auth, réseau...) vers le backend pour
/// qu'elles soient visibles dans Vercel (Deployments > Functions > Logs),
/// sans dépendre d'un accès physique au téléphone de l'utilisateur.
/// Best-effort : ne doit jamais lever d'exception ni bloquer l'app.
class RemoteLogger {
  static final _dio = Dio();

  static Future<void> log({
    required String context,
    required Object error,
    StackTrace? stack,
  }) async {
    try {
      String? code;
      String message = error.toString();
      if (error is FirebaseAuthException) {
        code = error.code;
        message = error.message ?? error.code;
      }
      await _dio.post(
        '${ApiConstants.baseUrl}/api/log',
        data: {
          'context': context,
          'message': message,
          'code': code,
          'stack': stack?.toString(),
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'platform': Platform.operatingSystem,
        },
        options: Options(sendTimeout: const Duration(seconds: 5)),
      );
    } catch (_) {
      // silencieux — le logging ne doit jamais casser le flux utilisateur
    }
  }

  /// Traduit une FirebaseAuthException en message lisible pour l'utilisateur,
  /// sans jamais afficher un message générique qui masque la vraie cause.
  static String readableAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Cet email est déjà utilisé par un autre compte.';
        case 'invalid-email':
          return 'Adresse email invalide.';
        case 'weak-password':
          return 'Mot de passe trop faible (6 caractères minimum).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email ou mot de passe incorrect.';
        case 'network-request-failed':
          return 'Pas de connexion réseau. Vérifiez votre connexion internet.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessayez dans quelques minutes.';
        case 'api-key-not-valid':
        case 'invalid-api-key':
          return 'Configuration Firebase invalide (clé API). Contactez le support.';
        default:
          return error.message ?? 'Erreur (${error.code}). Réessayez.';
      }
    }
    // Erreur Firestore (permission-denied = rules pas déployées, etc.)
    final msg = error.toString();
    if (msg.contains('permission-denied')) {
      return "Accès refusé par le serveur (règles de sécurité). Contactez le support.";
    }
    return 'Erreur inattendue : $msg';
  }
}
