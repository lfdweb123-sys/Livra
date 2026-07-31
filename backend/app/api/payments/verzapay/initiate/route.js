import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { verzapayCreatePayment } from '../../../../../lib/verzapay';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { orderId, rideId, phoneNumber } = await req.json();
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
    provider: 'verzapay',
    providerReference: null,
    status: 'pending',
    amount,
    currency: 'XOF',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  try {
    const result = await verzapayCreatePayment({
      amount,
      currency: 'XOF',
      description: `Livra ${orderId ? 'commande' : 'course'} ${orderId || rideId}`,
      customerName: auth.user.name,
      customerPhone: phoneNumber,
    });
    await paymentRef.update({ providerReference: result.id });
    return Response.json({ paymentId: paymentRef.id, checkoutUrl: result.checkout_url });
  } catch (e) {
    await paymentRef.update({ status: 'failed' });
    return jsonError(e.message, 400);
  }
}
