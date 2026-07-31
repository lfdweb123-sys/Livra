import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const input = searchParams.get('input');
  if (!input) return jsonError('input_required', 400);

  // biaisé Bénin/Afrique de l'Ouest — ajuster components selon pays cibles
  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(
    input
  )}&components=country:bj|country:ci|country:tg|country:sn|country:bf|country:ml&key=${process.env.GOOGLE_MAPS_SERVER_KEY}`;
  const res = await fetch(url);
  const data = await res.json();
  return Response.json(data);
}
