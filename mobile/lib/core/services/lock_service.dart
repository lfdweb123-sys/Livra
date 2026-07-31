import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// La biométrie ne remplace jamais Firebase Auth : elle déverrouille
/// localement une session déjà authentifiée. Le flag est stocké en
/// secure storage (pas SharedPreferences) car c'est un réglage de sécurité.
class LockService {
  static const _key = 'livra_biometric_enabled';
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _key);
    return value == 'true';
  }

  Future<void> setEnabled(bool value) async {
    await _storage.write(key: _key, value: value ? 'true' : 'false');
  }

  Future<bool> canUseBiometrics() => _localAuth.canCheckBiometrics;

  Future<bool> authenticate({String reason = 'Confirmez votre identité pour accéder à Livra'}) {
    return _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
    );
  }
}
