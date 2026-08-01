import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Verrouillage local de l'app. Le code PIN est le mécanisme fiable de base
/// (100% Flutter, aucune dépendance native fragile) ; la biométrie est une
/// option BONUS par-dessus, jamais seule — si elle échoue ou n'est pas
/// disponible, on retombe toujours sur le code PIN. Rien de tout ça ne
/// remplace Firebase Auth : c'est un verrou d'accès purement local.
class LockService {
  static const _lockEnabledKey = 'livra_lock_enabled';
  static const _pinHashKey = 'livra_pin_hash';
  static const _biometricEnabledKey = 'livra_biometric_enabled';

  final _storage = FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  String _hash(String pin) => sha256.convert(utf8.encode('livra_salt_$pin')).toString();

  Future<bool> isLockEnabled() async => (await _storage.read(key: _lockEnabledKey)) == 'true';

  Future<bool> hasPin() async => (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinHashKey, value: _hash(pin));
    await _storage.write(key: _lockEnabledKey, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  Future<void> disableLock() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.write(key: _lockEnabledKey, value: 'false');
    await _storage.write(key: _biometricEnabledKey, value: 'false');
  }

  Future<bool> isBiometricEnabled() async => (await _storage.read(key: _biometricEnabledKey)) == 'true';

  Future<void> setBiometricEnabled(bool value) async {
    await _storage.write(key: _biometricEnabledKey, value: value ? 'true' : 'false');
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Tente la biométrie native. Ne doit JAMAIS bloquer l'utilisateur :
  /// tout échec/exception doit permettre de retomber sur le code PIN.
  Future<bool> authenticateBiometric({String reason = 'Confirmez votre identité pour accéder à Livra'}) {
    return _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      authMessages: const [
        AndroidAuthMessages(
          signInTitle: 'Déverrouiller Livra',
          biometricHint: 'Vérification en cours',
          biometricNotRecognized: 'Non reconnu, réessayez',
          biometricRequiredTitle: 'Authentification requise',
          biometricSuccess: 'Authentification réussie',
          cancelButton: 'Utiliser le code PIN',
        ),
      ],
    );
  }
}
