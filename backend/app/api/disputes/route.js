import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';

// POST — signaler un vendeur, un restaurant, une boutique, un livreur, un
// coursier, un chauffeur, un taxi-moto OU un client. Tous les profils sans
// exception peuvent être signalés et sont traités de la même façon par
// l'équipe Livra (voir CGU: mêmes règles pour tous).
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { against, reason, description, relatedOrderId, relatedRideId } = await req.json();
  if (!against || !reason) return jsonError('against_and_reason_required', 400);

  const targetSnap = await db.collection('users').doc(against).get();
  if (!targetSnap.exists) return jsonError('target_not_found', 404);

  const ref = await db.collection('disputes').add({
    raisedBy: auth.uid,
    against,
    reason, // ex: 'not_received', 'fraud', 'abuse', 'bad_product', 'other'
    description: description || null,
    relatedOrderId: relatedOrderId || null,
    relatedRideId: relatedRideId || null,
    status: 'open',
    createdAt: FieldValue.serverTimestamp(),
  });

  // Notifie l'équipe admin (best-effort) — pas de userId admin unique fixe,
  // donc on se contente de journaliser; le tableau de bord admin liste déjà
  // les signalements ouverts (GET /api/admin/disputes).
  console.warn('[NEW_DISPUTE]', { id: ref.id, raisedBy: auth.uid, against, reason });

  return Response.json({ id: ref.id, status: 'open' });
}

// GET ?mine=1 — signalements déposés par l'utilisateur courant, pour qu'il
// puisse suivre leur statut depuis son profil.
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  try {
    const snap = await db
      .collection('disputes')
      .where('raisedBy', '==', auth.uid)
      .orderBy('createdAt', 'desc')
      .limit(30)
      .get();
    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[DISPUTES_GET_QUERY_ERROR]', { uid: auth.uid, message: e.message, code: e.code });
    return jsonError('disputes_query_failed', 500);
  }
}
