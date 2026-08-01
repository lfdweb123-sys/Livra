// Géocodage gratuit via OpenStreetMap Nominatim — aucune clé API, aucune
// carte bancaire requise (contrairement à Google Places/Geocoding).
// Usage raisonnable uniquement (politique Nominatim : ~1 req/s, User-Agent
// obligatoire) — suffisant pour le volume d'une app en démarrage.
const NOMINATIM_BASE = 'https://nominatim.openstreetmap.org';
const USER_AGENT = 'Livra/1.0 (contact@livra.app)';

export async function searchAddress(query, countryCodes = 'bj,tg,ci,cg,sn,bf,ml') {
  const url = `${NOMINATIM_BASE}/search?q=${encodeURIComponent(query)}&format=json&addressdetails=1&limit=6&countrycodes=${countryCodes}`;
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
  if (!res.ok) throw new Error('nominatim_search_failed');
  const data = await res.json();
  return data.map((d) => ({
    label: d.display_name,
    lat: parseFloat(d.lat),
    lng: parseFloat(d.lon),
  }));
}

export async function reverseGeocode(lat, lng) {
  const url = `${NOMINATIM_BASE}/reverse?lat=${lat}&lon=${lng}&format=json&addressdetails=1`;
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
  if (!res.ok) throw new Error('nominatim_reverse_failed');
  const data = await res.json();
  const addr = data.address || {};
  return addr.city || addr.town || addr.village || addr.municipality || addr.county || data.display_name || `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
}
