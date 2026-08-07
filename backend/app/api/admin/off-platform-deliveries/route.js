import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

// GET — admin uniquement. Liste les numéros de livreurs/chauffeurs HORS
// APPLICATION déclarés par des clients ou des vendeurs, pour suivi.
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  try {
    const snap = await db.collection('off_platform_deliveries').orderBy('createdAt', 'desc').limit(200).get();
    const items = await Promise.all(
      snap.docs.map(async (d) => {
        const data = d.data();
        let declaredByName = null;
        try {
          const userSnap = await db.collection('users').doc(data.declaredBy).get();
          declaredByName = userSnap.exists ? userSnap.data().name : null;
        } catch (e) {
          // best-effort
        }
        return { id: d.id, ...data, declaredByName };
      })
    );
    return Response.json({ items });
  } catch (e) {
    console.error('[OFF_PLATFORM_DELIVERIES_GET_ERROR]', { message: e.message, code: e.code });
    return jsonError('off_platform_deliveries_query_failed', 500);
  }
}
