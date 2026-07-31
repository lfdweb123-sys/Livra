import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);
  const snap = await db.collection('disputes').orderBy('createdAt', 'desc').limit(50).get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}

// PATCH { id, status, resolution }
export async function PATCH(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);
  const { id, status, resolution } = await req.json();
  await db.collection('disputes').doc(id).update({
    status,
    resolution: resolution || null,
    resolvedAt: FieldValue.serverTimestamp(),
  });
  return Response.json({ ok: true });
}
