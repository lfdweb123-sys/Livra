import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { logActivity } from '../../../lib/activityLog';
import { sendNotification } from '../../../lib/fcm';
import { sendTransactionalEmail } from '../../../lib/brevo';

// POST { orderId | rideId, rating (1-5), comment }
// Un avis n'est possible QUE sur une commande livrée / course terminée dont
// on est bien le client, et une seule fois par commande/course — vérifié
// ici, jamais fait confiance au client.
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { orderId, rideId, rating, comment } = await req.json();
  if (!orderId && !rideId) return jsonError('orderId_or_rideId_required', 400);
  if (!rating || rating < 1 || rating > 5) return jsonError('invalid_rating', 400);

  const sourceCollection = orderId ? 'orders' : 'rides';
  const sourceId = orderId || rideId;
  const sourceSnap = await db.collection(sourceCollection).doc(sourceId).get();
  if (!sourceSnap.exists) return jsonError('not_found', 404);
  const source = sourceSnap.data();

  if (source.clientId !== auth.uid) return jsonError('forbidden', 403);

  const doneStatus = orderId ? 'delivered' : 'completed';
  if (source.status !== doneStatus) return jsonError('not_yet_completed', 400);

  const existing = await db
    .collection('reviews')
    .where(orderId ? 'orderId' : 'rideId', '==', sourceId)
    .limit(1)
    .get();
  if (!existing.empty) return jsonError('already_reviewed', 400);

  // Nourriture/colis -> avis sur le vendeur (s'il y en a un) ET/OU le
  // livreur ; course -> avis sur le chauffeur uniquement.
  const targets = [];
  if (orderId && source.vendorId) targets.push({ type: 'vendor', id: source.vendorId, collection: 'vendors' });
  if (source.driverId) targets.push({ type: 'driver', id: source.driverId, collection: 'drivers' });
  if (targets.length === 0) return jsonError('no_target_to_review', 400);

  const batch = db.batch();
  // Demande explicite: afficher le nom + avatar de l'auteur de l'avis —
  // on les stocke directement sur le document au moment de la création
  // (pas de jointure à refaire à chaque lecture).
  const clientSnap = await db.collection('users').doc(auth.uid).get();
  const clientName = clientSnap.exists ? clientSnap.data().name : 'Client Livra';
  const clientPhotoUrl = clientSnap.exists ? clientSnap.data().photoUrl || null : null;

  for (const target of targets) {
    const reviewRef = db.collection('reviews').doc();
    batch.set(reviewRef, {
      targetType: target.type,
      targetId: target.id,
      orderId: orderId || null,
      rideId: rideId || null,
      clientId: auth.uid,
      clientName,
      clientPhotoUrl,
      rating,
      comment: comment || '',
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  // Recalcule la moyenne de chaque cible (transaction pour éviter les
  // courses concurrentes entre plusieurs avis en même temps).
  for (const target of targets) {
    const targetRef = db.collection(target.collection).doc(target.id);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(targetRef);
      if (!snap.exists) return;
      const data = snap.data();
      const oldCount = data.ratingCount || 0;
      const oldRating = data.rating || 0;
      const newCount = oldCount + 1;
      const newRating = (oldRating * oldCount + rating) / newCount;
      tx.update(targetRef, { rating: newRating, ratingCount: newCount });
    });

    // Demande explicite: notifier par push ET par mail quand un avis est
    // laissé — celui qui reçoit l'avis doit être prévenu immédiatement.
    try {
      const targetSnap = await targetRef.get();
      if (targetSnap.exists) {
        const ownerId = targetSnap.data().ownerId;
        const ownerSnap = await db.collection('users').doc(ownerId).get();
        const stars = '⭐'.repeat(rating);
        await sendNotification({
          userId: ownerId,
          title: 'Nouvel avis reçu',
          body: `${clientName} vous a laissé ${rating}/5 ${stars}${comment ? ' — ' + comment : ''}`,
          type: 'review_received',
          relatedId: orderId || rideId,
        });
        if (ownerSnap.exists && ownerSnap.data().email) {
          await sendTransactionalEmail({
            to: ownerSnap.data().email,
            toName: ownerSnap.data().name,
            subject: 'Nouvel avis reçu sur Livra',
            htmlContent: `<p>${clientName} vous a laissé un avis : <strong>${rating}/5</strong> ${stars}</p>${comment ? `<p>"${comment}"</p>` : ''}`,
          });
        }
      }
    } catch (e) {
      console.error('[REVIEW_NOTIFICATION_ERROR]', target.id, e.message);
    }
  }

  await logActivity('review_created', `Nouvel avis (${rating}/5) sur ${targets.map((t) => t.type).join(' + ')}`, {
    clientId: auth.uid,
    orderId,
    rideId,
  });

  return Response.json({ ok: true });
}

// GET ?targetType=vendor|driver&targetId=X — avis d'une cible, plus récents d'abord
export const dynamic = 'force-dynamic';

export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const targetType = searchParams.get('targetType');
  const targetId = searchParams.get('targetId');
  if (!targetType || !targetId) return jsonError('targetType_and_targetId_required', 400);

  try {
    const snap = await db
      .collection('reviews')
      .where('targetType', '==', targetType)
      .where('targetId', '==', targetId)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[REVIEWS_GET_QUERY_ERROR]', { targetType, targetId, message: e.message, code: e.code });
    return jsonError('reviews_query_failed', 500);
  }
}
