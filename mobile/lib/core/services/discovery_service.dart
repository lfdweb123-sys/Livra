import 'api/api_client.dart';

class DiscoveryService {
  Future<List<Map<String, dynamic>>> featuredProducts() async {
    final res = await ApiClient.instance.get('/api/products/featured');
    return List<Map<String, dynamic>>.from(res['items'] ?? []);
  }

  Future<void> trackImpression(String campaignId) {
    return ApiClient.instance.post('/api/ads/track', data: {'campaignId': campaignId, 'type': 'impression'});
  }

  Future<void> trackClick(String campaignId) {
    return ApiClient.instance.post('/api/ads/track', data: {'campaignId': campaignId, 'type': 'click'});
  }
}
