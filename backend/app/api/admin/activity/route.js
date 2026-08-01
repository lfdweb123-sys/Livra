import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

// Lecture seule — le journal de toutes les actions automatisées de la
// plateforme (candidatures, paiements, litiges...). L'admin observe, il
// n'approuve rien ici.
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const { searchParams } = new URL(req.url);
  const limit = Math.min(parseInt(searchParams.get('limit') || '50', 10), 100);
  const snap = await db.collection('activity_logs').orderBy('createdAt', 'desc').limit(limit).get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}
