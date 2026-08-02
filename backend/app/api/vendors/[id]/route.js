import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendTransactionalEmail, vendorStatusEmail } from '../../../../lib/brevo';
import { logActivity } from '../../../../lib/activityLog';
import { sendNotification } from '../../../../lib/fcm';

export async function GET(req, { params }) {
  const snap = await db.collection('vendors').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

// PATCH — le vendeur modifie son catalogue/infos ; seul l'admin change status/commission
export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const ref = db.collection('vendors').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const vendor = snap.data();

  const body = await req.json();
  const update = { updatedAt: FieldValue.serverTimestamp() };

  if (auth.role === 'admin') {
    if (body.status) update.status = body.status; // active | suspended | rejected
    if (body.status === 'rejected' && body.rejectionReason) update.rejectionReason = body.rejectionReason;
    if (body.commission !== undefined) update.commission = body.commission;
  } else if (auth.uid === vendor.ownerId) {
    ['businessName', 'address', 'coverImageUrl', 'logoUrl', 'isOpen', 'description', 'deliveryFee'].forEach((k) => {
      if (body[k] !== undefined) update[k] = body[k];
    });
  } else {
    return jsonError('forbidden', 403);
  }

  await ref.update(update);

  if (auth.role === 'admin' && (body.status === 'active' || body.status === 'rejected')) {
    try {
      const ownerSnap = await db.collection('users').doc(vendor.ownerId).get();
      if (ownerSnap.exists) {
        const { subject, htmlContent } = vendorStatusEmail(vendor.businessName, body.status, body.rejectionReason);
        const email = ownerSnap.data().email;
        if (email) {
          const emailResult = await sendTransactionalEmail({ to: email, toName: ownerSnap.data().name, subject, htmlContent });
          console.log('[VENDOR_STATUS_EMAIL]', vendor.ownerId, emailResult);
        } else {
          console.error('[VENDOR_STATUS_EMAIL] pas d\'email pour', vendor.ownerId);
        }

        const pushResult = await sendNotification({
          userId: vendor.ownerId,
          title: body.status === 'active' ? 'Boutique validée !' : 'Candidature refusée',
          body: body.status === 'active'
            ? `Votre boutique "${vendor.businessName}" est maintenant active. Vous pouvez publier votre catalogue.`
            : `Votre candidature pour "${vendor.businessName}" n'a pas été retenue.${body.rejectionReason ? ` Motif : ${body.rejectionReason}.` : ''}`,
          type: 'vendor_status',
          relatedId: params.id,
        });
        console.log('[VENDOR_STATUS_PUSH]', vendor.ownerId, pushResult);
      } else {
        console.error('[VENDOR_STATUS_NOTIF] user introuvable', vendor.ownerId);
      }
    } catch (e) {
      console.error('[VENDOR_STATUS_NOTIF_ERROR]', e.message, e.stack);
    }

    await logActivity(
      body.status === 'active' ? 'vendor_approved' : 'vendor_rejected',
      `Vendeur "${vendor.businessName}" ${body.status === 'active' ? 'approuvé' : 'rejeté'} par l'admin${body.rejectionReason ? ` — ${body.rejectionReason}` : ''}`,
      { vendorId: params.id, adminUid: auth.uid }
    );
  }

  return Response.json({ ok: true });
}

// DELETE — admin uniquement, suppression définitive (non-respect des règles)
export async function DELETE(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const snap = await db.collection('vendors').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);

  await logActivity('vendor_deleted', `Vendeur "${snap.data().businessName}" supprimé par l'admin`, { vendorId: params.id, adminUid: auth.uid });

  const productsSnap = await db.collection(`vendors/${params.id}/products`).get();
  const batch = db.batch();
  productsSnap.docs.forEach((doc) => batch.delete(doc.ref));
  batch.delete(db.collection('vendors').doc(params.id));
  await batch.commit();

  return Response.json({ ok: true });
}
