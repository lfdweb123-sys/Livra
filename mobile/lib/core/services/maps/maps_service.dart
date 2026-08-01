import '../api/api_client.dart';
import '../../constants/api_constants.dart';

/// Recherche d'adresse et itinéraire — tout passe par le backend, qui
/// utilise OpenStreetMap (Nominatim + OSRM), gratuit et sans clé API.
/// Aucune carte bancaire / compte de facturation requis (contrairement à
/// Google Maps Platform).
class MapsService {
  final _api = ApiClient.instance;

  /// Recherche d'adresse texte -> liste de résultats {label, lat, lng}
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.trim().length < 3) return [];
    final res = await _api.get(ApiConstants.placesAutocomplete, query: {'input': query});
    return List<Map<String, dynamic>>.from(res['predictions'] ?? []);
  }

  /// Itinéraire entre deux points -> {coordinates: [[lat,lng],...], distanceKm, durationMin}
  Future<Map<String, dynamic>> directions({required String origin, required String destination}) {
    return _api.get(ApiConstants.directions, query: {'origin': origin, 'destination': destination});
  }

  /// Nom de ville à partir d'une position GPS — utilisé pour personnaliser
  /// les textes ("livré partout à <ville>") sans ville fixe codée en dur.
  /// Appel public, ne nécessite pas d'être connecté (utilisé dès l'onboarding).
  Future<String?> reverseGeocodeCity(double lat, double lng) async {
    try {
      final res = await _api.get('/api/maps/reverse-geocode', query: {'lat': lat.toString(), 'lng': lng.toString()});
      return res['label'] as String?;
    } catch (_) {
      return null;
    }
  }
}
