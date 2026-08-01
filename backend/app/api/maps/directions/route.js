import { requireAuth, jsonError } from '../../../../lib/auth';
import { getRoute } from '../../../../lib/routing';

// origin/destination au format "lat,lng"
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const origin = searchParams.get('origin');
  const destination = searchParams.get('destination');
  if (!origin || !destination) return jsonError('origin_destination_required', 400);

  const [originLat, originLng] = origin.split(',').map(Number);
  const [destLat, destLng] = destination.split(',').map(Number);

  try {
    const route = await getRoute({ originLat, originLng, destLat, destLng });
    return Response.json(route);
  } catch (e) {
    return jsonError(e.message, 502);
  }
}
