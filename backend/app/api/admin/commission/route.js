import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const snap = await db.collection('commission_config').doc('default').get();
  return Response.json(snap.exists ? snap.data() : { defaultCommissionPercent: 15 });
}

export async function PATCH(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);
  const { defaultCommissionPercent } = await req.json();
  await db.collection('commission_config').doc('default').set(
    { defaultCommissionPercent, updatedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  return Response.json({ ok: true });
}
