import { jsonError } from '../../../../lib/auth';
import { reverseGeocode } from '../../../../lib/geocoding';

// Public (pas de requireAuth) : appelé depuis l'onboarding, AVANT que
// l'utilisateur soit connecté.
export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const lat = parseFloat(searchParams.get('lat'));
  const lng = parseFloat(searchParams.get('lng'));
  if (isNaN(lat) || isNaN(lng)) return jsonError('lat_lng_required', 400);

  try {
    const label = await reverseGeocode(lat, lng);
    return Response.json({ label });
  } catch (e) {
    return jsonError(e.message, 502);
  }
}
