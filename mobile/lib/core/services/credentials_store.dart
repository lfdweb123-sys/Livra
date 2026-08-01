import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stocke email/mot de passe localement (secure storage chiffré) si
/// l'utilisateur coche "Se souvenir de moi". Ce n'est pas un token de
/// session Firebase — juste un pré-remplissage pratique du formulaire de
/// connexion, à la demande explicite de l'utilisateur.
class CredentialsStore {
  static const _emailKey = 'livra_saved_email';
  static const _passwordKey = 'livra_saved_password';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String email, String password) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  Future<({String email, String password})?> read() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }
}
