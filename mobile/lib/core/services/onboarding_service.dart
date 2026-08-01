import 'package:shared_preferences/shared_preferences.dart';

/// Persisté via SharedPreferences — donc réinitialisé automatiquement si
/// l'utilisateur vide le cache/les données de l'app, comme demandé.
class OnboardingService {
  static const _key = 'livra_onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
