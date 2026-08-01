import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendTransactionalEmail, driverStatusEmail } from '../../../../lib/brevo';
import { logActivity } from '../../../../lib/activityLog';

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
    const ownerSnap = await db.collection('users').doc(driver.ownerId).get();
    if (ownerSnap.exists) {
      const { subject, htmlContent } = driverStatusEmail(body.status, body.rejectionReason);
      const email = ownerSnap.data().email;
      if (email) await sendTransactionalEmail({ to: email, toName: ownerSnap.data().name, subject, htmlContent });
    }
    await logActivity(
      body.status === 'active' ? 'driver_approved' : 'driver_rejected',
      `Livreur/chauffeur (${driver.vehicleType}) ${body.status === 'active' ? 'approuvé' : 'rejeté'} par l'admin${body.rejectionReason ? ` — ${body.rejectionReason}` : ''}`,
      { driverId: params.id, adminUid: auth.uid }
    );
  }

  return Response.json({ ok: true });
}
