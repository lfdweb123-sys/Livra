import { requireAuth, jsonError } from '../../../../lib/auth';
import { searchAddress } from '../../../../lib/geocoding';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const input = searchParams.get('input');
  if (!input || input.trim().length < 3) return Response.json({ predictions: [] });

  try {
    const results = await searchAddress(input.trim());
    return Response.json({ predictions: results });
  } catch (e) {
    return jsonError(e.message, 502);
  }
}
