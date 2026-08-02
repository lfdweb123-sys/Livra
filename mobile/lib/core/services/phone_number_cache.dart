import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise le dernier numéro Mobile Money utilisé pour pré-remplir le
/// prochain paiement (dépôt, commande, course...) sans avoir à le retaper.
class PhoneNumberCache {
  static const _key = 'livra_last_phone_number';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> save(String fullNumber) async {
    if (fullNumber.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, fullNumber);
  }
}
