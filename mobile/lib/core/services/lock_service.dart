import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// La biométrie ne remplace jamais Firebase Auth : elle déverrouille
/// localement une session déjà authentifiée. Le flag est stocké en
/// secure storage (pas SharedPreferences) car c'est un réglage de sécurité.
class LockService {
  static const _key = 'livra_biometric_enabled';
  final _storage = FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _key);
    return value == 'true';
  }

  Future<void> setEnabled(bool value) async {
    await _storage.write(key: _key, value: value ? 'true' : 'false');
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

  Future<bool> authenticate({String reason = 'Confirmez votre identité pour accéder à Livra'}) {
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
