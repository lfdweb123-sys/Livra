import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { feexpayRequestToPay } from '../../../../../lib/feexpay';

// POST { orderId?, rideId?, network, phoneNumber, otp? }
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { orderId, rideId, network, phoneNumber, otp } = await req.json();
  if (!orderId && !rideId) return jsonError('orderId_or_rideId_required', 400);

  const targetRef = db.collection(orderId ? 'orders' : 'rides').doc(orderId || rideId);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) return jsonError('not_found', 404);
  const target = targetSnap.data();
  if (target.clientId !== auth.uid) return jsonError('forbidden', 403);

  const amount = target.priceBreakdown ? target.priceBreakdown.total : target.price;

  const paymentRef = await db.collection('payments').add({
    orderId: orderId || null,
    rideId: rideId || null,
    userId: auth.uid,
    provider: 'feexpay',
    providerReference: null,
    status: 'pending',
    amount,
    currency: 'XOF',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  try {
    const result = await feexpayRequestToPay({
      network,
      phoneNumber,
      amount,
      description: `Livra ${orderId ? 'commande' : 'course'} ${orderId || rideId}`,
      callbackInfo: paymentRef.id,
      otp,
    });
    await paymentRef.update({ providerReference: result.reference || result.order_id || null });
    return Response.json({ paymentId: paymentRef.id, ...result });
  } catch (e) {
    await paymentRef.update({ status: 'failed' });
    return jsonError(e.message, 400);
  }
}
