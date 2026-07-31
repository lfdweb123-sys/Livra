// Format geoflutterfire2-compatible: { geohash, geopoint: {latitude, longitude} }
import geohashLib from 'ngeohash';

export function toGeoPoint(lat, lng) {
  return {
    geohash: geohashLib.encode(lat, lng, 9),
    geopoint: { latitude: lat, longitude: lng },
  };
}

// Distance haversine en km, pour calculs de prix côté serveur (pas de confiance client)
export function distanceKm(a, b) {
  const R = 6371;
  const dLat = ((b.latitude - a.latitude) * Math.PI) / 180;
  const dLng = ((b.longitude - a.longitude) * Math.PI) / 180;
  const lat1 = (a.latitude * Math.PI) / 180;
  const lat2 = (b.latitude * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
