import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';

// GET — détail complet d'une annonce, y compris le contact du vendeur
// (annonces actives uniquement pour un utilisateur normal — le but même
// de cette page est de permettre au client intéressé de le contacter).
export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const snap = await db.collection('classified_listings').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  const listing = snap.data();

  if (auth.role !== 'admin' && listing.ownerId !== auth.uid && listing.status !== 'active') {
    return jsonError('forbidden', 403);
  }

  return Response.json({ id: snap.id, ...listing });
}

// PATCH { status?, title?, description?, price?, imageUrl?, rejectionReason? }
export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const ref = db.collection('classified_listings').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const listing = snap.data();

  const body = await req.json();
  const update = { updatedAt: FieldValue.serverTimestamp() };

  if (auth.role === 'admin') {
    // Approbation/rejet — la vérification d'identité du vendeur est
    // validée EN MÊME TEMPS que la première annonce (voir POST), pas
    // séparément.
    if (body.status) {
      update.status = body.status;
      if (body.status === 'rejected' && body.rejectionReason) update.rejectionReason = body.rejectionReason;
      if (body.status === 'active') {
        await db.collection('users').doc(listing.ownerId).update({ classifiedsIdentityStatus: 'verified' }).catch(() => {});
      }
    }
  } else if (listing.ownerId === auth.uid) {
    // Le propriétaire peut modifier son annonce (retour en attente de
    // revue si le contenu change) ou la marquer vendue.
    if (body.status === 'sold') {
      update.status = 'sold';
    } else {
      ['title', 'description', 'price', 'imageUrl', 'contactPhone'].forEach((k) => {
        if (body[k] !== undefined) update[k] = body[k];
      });
      if (Object.keys(update).length > 1) update.status = 'pending'; // repasse en revue si modifiée
    }
  } else {
    return jsonError('forbidden', 403);
  }

  await ref.update(update);

  if (update.status === 'active' || update.status === 'rejected') {
    await sendNotification({
      userId: listing.ownerId,
      title: update.status === 'active' ? 'Annonce publiée' : 'Annonce rejetée',
      body: update.status === 'active'
        ? `Votre annonce "${listing.title}" est maintenant visible.`
        : `Votre annonce "${listing.title}" a été rejetée${body.rejectionReason ? ' : ' + body.rejectionReason : '.'}`,
      type: update.status === 'active' ? 'classified_approved' : 'classified_rejected',
      relatedId: params.id,
    });
  }

  return Response.json({ ok: true });
}

// DELETE — le propriétaire ou l'admin peut retirer une annonce.
export async function DELETE(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const ref = db.collection('classified_listings').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  if (auth.role !== 'admin' && snap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  await ref.delete();
  return Response.json({ ok: true });
}
