import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { toGeoPoint } from '../../../../../lib/geo';

// POST { isOnline, lat, lng } — appelé à chaque toggle et à chaque update GPS pendant que le chauffeur est en ligne
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const ref = db.collection('drivers').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  if (snap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);
  if (snap.data().status !== 'active') return jsonError('driver_not_active', 403);

  const { isOnline, lat, lng } = await req.json();
  const update = { isOnline, updatedAt: FieldValue.serverTimestamp() };
  if (lat !== undefined && lng !== undefined) update.position = toGeoPoint(lat, lng);
  await ref.update(update);
  return Response.json({ ok: true });
}
