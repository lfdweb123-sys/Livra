import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendTransactionalEmail, driverStatusEmail } from '../../../../lib/brevo';
import { logActivity } from '../../../../lib/activityLog';
import { sendNotification } from '../../../../lib/fcm';

export async function GET(req, { params }) {
  const snap = await db.collection('drivers').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const ref = db.collection('drivers').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const driver = snap.data();

  const body = await req.json();
  const update = { updatedAt: FieldValue.serverTimestamp() };

  if (auth.role === 'admin') {
    if (body.status) update.status = body.status;
    if (body.status === 'rejected' && body.rejectionReason) update.rejectionReason = body.rejectionReason;
  } else if (auth.uid === driver.ownerId) {
    if (body.documentsR2) update.documentsR2 = body.documentsR2;
    if (body.photoUrl !== undefined) update.photoUrl = body.photoUrl;
    if (body.bio !== undefined) update.bio = body.bio;
  } else {
    return jsonError('forbidden', 403);
  }
  await ref.update(update);

  if (auth.role === 'admin' && (body.status === 'active' || body.status === 'rejected')) {
    try {
      const ownerSnap = await db.collection('users').doc(driver.ownerId).get();
      if (ownerSnap.exists) {
        const { subject, htmlContent } = driverStatusEmail(body.status, body.rejectionReason);
        const email = ownerSnap.data().email;
        if (email) {
          const emailResult = await sendTransactionalEmail({ to: email, toName: ownerSnap.data().name, subject, htmlContent });
          console.log('[DRIVER_STATUS_EMAIL]', driver.ownerId, emailResult);
        } else {
          console.error('[DRIVER_STATUS_EMAIL] pas d\'email pour', driver.ownerId);
        }

        const pushResult = await sendNotification({
          userId: driver.ownerId,
          title: body.status === 'active' ? 'Compte livreur validé !' : 'Candidature refusée',
          body: body.status === 'active'
            ? 'Vous pouvez passer en ligne dans l\'app pour recevoir vos premières courses.'
            : `Votre candidature n'a pas été retenue.${body.rejectionReason ? ` Motif : ${body.rejectionReason}.` : ''}`,
          type: 'driver_status',
          relatedId: params.id,
        });
        console.log('[DRIVER_STATUS_PUSH]', driver.ownerId, pushResult);
      } else {
        console.error('[DRIVER_STATUS_NOTIF] user introuvable', driver.ownerId);
      }
    } catch (e) {
      console.error('[DRIVER_STATUS_NOTIF_ERROR]', e.message, e.stack);
    }

    await logActivity(
      body.status === 'active' ? 'driver_approved' : 'driver_rejected',
      `Livreur/chauffeur (${driver.vehicleType}) ${body.status === 'active' ? 'approuvé' : 'rejeté'} par l'admin${body.rejectionReason ? ` — ${body.rejectionReason}` : ''}`,
      { driverId: params.id, adminUid: auth.uid }
    );
  }

  return Response.json({ ok: true });
}

// DELETE — admin uniquement, suppression définitive (non-respect des règles)
export async function DELETE(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const snap = await db.collection('drivers').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);

  await logActivity('driver_deleted', `Livreur/chauffeur (${snap.data().vehicleType}) supprimé par l'admin`, { driverId: params.id, adminUid: auth.uid });
  await db.collection('drivers').doc(params.id).delete();
  return Response.json({ ok: true });
}
