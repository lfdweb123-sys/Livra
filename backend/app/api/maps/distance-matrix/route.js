import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const origins = searchParams.get('origins');
  const destinations = searchParams.get('destinations');
  if (!origins || !destinations) return jsonError('origins_destinations_required', 400);

  const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origins}&destinations=${destinations}&key=${process.env.GOOGLE_MAPS_SERVER_KEY}`;
  const res = await fetch(url);
  const data = await res.json();
  return Response.json(data);
}
