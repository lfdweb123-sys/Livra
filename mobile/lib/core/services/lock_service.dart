import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Verrouillage par empreinte digitale (biométrie native). Ne remplace
/// jamais Firebase Auth : déverrouille localement une session déjà
/// authentifiée.
class LockService {
  static const _lockEnabledKey = 'livra_lock_enabled';
  final _storage = FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  Future<bool> isLockEnabled() async => (await _storage.read(key: _lockEnabledKey)) == 'true';

  Future<void> setLockEnabled(bool value) async {
    await _storage.write(key: _lockEnabledKey, value: value ? 'true' : 'false');
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

  Future<bool> authenticateBiometric({String reason = 'Confirmez votre identité pour accéder à Livra'}) {
    return _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true, useErrorDialogs: true),
      authMessages: const [
        AndroidAuthMessages(
          signInTitle: 'Déverrouiller Livra',
          biometricHint: 'Vérification en cours',
          biometricNotRecognized: 'Non reconnu, réessayez',
          biometricRequiredTitle: 'Authentification requise',
          biometricSuccess: 'Authentification réussie',
          cancelButton: 'Annuler',
          deviceCredentialsRequiredTitle: 'Code de sécurité requis',
          deviceCredentialsSetupDescription: 'Configurez un verrouillage d\'écran dans les réglages du téléphone',
          goToSettingsButton: 'Aller aux réglages',
          goToSettingsDescription: 'Aucune empreinte enregistrée. Ajoutez-en une dans les réglages du téléphone.',
        ),
      ],
    );
  }
}
