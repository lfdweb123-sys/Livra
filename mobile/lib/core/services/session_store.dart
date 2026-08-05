import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mémorise la date de la dernière connexion MANUELLE (login ou inscription
/// via formulaire, jamais une reconnexion automatique) afin d'imposer une
/// déconnexion automatique après 30 jours. Firebase Auth garde sa session
/// active indéfiniment par défaut — c'est cette limite de 30 jours qui vient
/// s'ajouter par-dessus, vérifiée une fois au démarrage de l'app.
class SessionStore {
  static const _loginAtKey = 'livra_session_login_at';
  static const Duration maxSessionAge = Duration(days: 30);
  final _storage = const FlutterSecureStorage();

  Future<void> recordLogin() async {
    await _storage.write(
      key: _loginAtKey,
      value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _loginAtKey);
  }

  /// true si aucune date de connexion n'est connue, ou si plus de 30 jours
  /// se sont écoulés depuis la dernière connexion manuelle.
  Future<bool> isExpired() async {
    final raw = await _storage.read(key: _loginAtKey);
    if (raw == null) return true;
    final loginAt = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(raw) ?? 0,
        isUtc: true);
    return DateTime.now().toUtc().difference(loginAt) > maxSessionAge;
  }
}
