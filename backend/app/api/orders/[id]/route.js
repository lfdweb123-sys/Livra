import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';
import { sendTransactionalEmail, orderDeliveredEmail } from '../../../../lib/brevo';

const VENDOR_ALLOWED = ['accepted', 'preparing', 'picked_up'];
const DRIVER_ALLOWED = ['picked_up', 'delivering', 'delivered'];

export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const snap = await db.collection('orders').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

// PATCH { status } — transition contrôlée selon le rôle
export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { status, driverId } = await req.json();
  const ref = db.collection('orders').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const order = snap.data();

  const isClientCancel = auth.role === 'client' && order.clientId === auth.uid && order.status === 'pending' && status === 'cancelled';
  const isVendorMove = auth.role === 'vendor' && VENDOR_ALLOWED.includes(status);
  const isDriverMove = auth.role === 'driver' && DRIVER_ALLOWED.includes(status);
  const isAdmin = auth.role === 'admin';

  if (!(isClientCancel || isVendorMove || isDriverMove || isAdmin)) return jsonError('forbidden', 403);

  const update = {
    status,
    updatedAt: FieldValue.serverTimestamp(),
    statusHistory: FieldValue.arrayUnion({ status, at: new Date().toISOString(), by: auth.uid }),
  };
  // un livreur qui accepte une commande "picked_up" venant de vendeur s'auto-assigne s'il n'y a pas encore de driverId
  if (status === 'picked_up' && !order.driverId && driverId) update.driverId = driverId;

  await ref.update(update);

  await sendNotification({
    userId: order.clientId,
    title: 'Commande mise à jour',
    body: `Votre commande est maintenant: ${status}`,
    type: 'order_update',
    relatedId: params.id,
  });

  if (status === 'delivered') {
    const clientSnap = await db.collection('users').doc(order.clientId).get();
    if (clientSnap.exists && clientSnap.data().email) {
      const { subject, htmlContent } = orderDeliveredEmail(params.id, order.priceBreakdown?.total);
      await sendTransactionalEmail({ to: clientSnap.data().email, toName: clientSnap.data().name, subject, htmlContent });
    }
  }

  return Response.json({ ok: true });
}
