// Itinéraire gratuit via OSRM (serveur de démo public) — pas de clé API.
// Limite : serveur partagé public, pas de SLA. Convient pour un MVP ; si le
// volume grossit, prévoir un serveur OSRM auto-hébergé (toujours gratuit,
// juste une VM à payer, sans carte "API billing" façon Google).
const OSRM_BASE = 'https://router.project-osrm.org';

export async function getRoute({ originLat, originLng, destLat, destLng, profile = 'driving' }) {
  const url = `${OSRM_BASE}/route/v1/${profile}/${originLng},${originLat};${destLng},${destLat}?overview=full&geometries=geojson`;
  const res = await fetch(url);
  if (!res.ok) throw new Error('osrm_route_failed');
  const data = await res.json();
  if (data.code !== 'Ok' || !data.routes?.length) throw new Error('osrm_no_route');
  const route = data.routes[0];
  // GeoJSON = [lng, lat] — on inverse en [lat, lng] pour coller à LatLng côté Flutter
  const coordinates = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
  return {
    coordinates,
    distanceKm: Number((route.distance / 1000).toFixed(2)),
    durationMin: Math.round(route.duration / 60),
  };
}
