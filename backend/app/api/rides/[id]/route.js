import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';

const DRIVER_ALLOWED = ['accepted', 'arriving', 'in_progress', 'completed'];

export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const snap = await db.collection('rides').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { status, driverId } = await req.json();
  const ref = db.collection('rides').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const ride = snap.data();

  const isClientCancel = auth.role === 'client' && ride.clientId === auth.uid && ride.status === 'pending' && status === 'cancelled';
  const isDriverMove = auth.role === 'driver' && DRIVER_ALLOWED.includes(status);
  const isAdmin = auth.role === 'admin';
  if (!(isClientCancel || isDriverMove || isAdmin)) return jsonError('forbidden', 403);

  const update = { status, updatedAt: FieldValue.serverTimestamp() };
  if (status === 'accepted' && !ride.driverId && driverId) update.driverId = driverId;

  await ref.update(update);
  await sendNotification({
    userId: ride.clientId,
    title: 'Course mise à jour',
    body: `Votre course est maintenant: ${status}`,
    type: 'ride_update',
    relatedId: params.id,
  });
  return Response.json({ ok: true });
}
