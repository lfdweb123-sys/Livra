/// Format compatible geoflutterfire_plus: { geohash, geopoint: {latitude, longitude} }
class LivraGeoPoint {
  final String geohash;
  final double latitude;
  final double longitude;

  LivraGeoPoint({required this.geohash, required this.latitude, required this.longitude});

  factory LivraGeoPoint.fromMap(Map<String, dynamic> map) {
    final geopoint = map['geopoint'] as Map<String, dynamic>? ?? {};
    return LivraGeoPoint(
      geohash: map['geohash'] ?? '',
      latitude: (geopoint['latitude'] ?? 0).toDouble(),
      longitude: (geopoint['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'geohash': geohash,
        'geopoint': {'latitude': latitude, 'longitude': longitude},
      };
}
