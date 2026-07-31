import '../api/api_client.dart';
import '../../constants/api_constants.dart';

/// Toutes les requêtes Directions/Distance Matrix/Places passent par le
/// backend (clé Google Maps jamais exposée côté mobile).
class MapsService {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> directions({required String origin, required String destination}) {
    return _api.get(ApiConstants.directions, query: {'origin': origin, 'destination': destination});
  }

  Future<Map<String, dynamic>> distanceMatrix({required String origins, required String destinations}) {
    return _api.get(ApiConstants.distanceMatrix, query: {'origins': origins, 'destinations': destinations});
  }

  Future<List<dynamic>> placesAutocomplete(String input) async {
    final res = await _api.get(ApiConstants.placesAutocomplete, query: {'input': input});
    return res['predictions'] ?? [];
  }
}
