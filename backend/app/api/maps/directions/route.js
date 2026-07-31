// Proxy Directions API — clé Maps jamais exposée côté client
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const origin = searchParams.get('origin');
  const destination = searchParams.get('destination');
  if (!origin || !destination) return jsonError('origin_destination_required', 400);

  const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin}&destination=${destination}&key=${process.env.GOOGLE_MAPS_SERVER_KEY}`;
  const res = await fetch(url);
  const data = await res.json();
  return Response.json(data);
}
