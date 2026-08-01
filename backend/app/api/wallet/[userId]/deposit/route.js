import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { feexpayRequestToPay } from '../../../../../lib/feexpay';
import { verzapayCreatePayment } from '../../../../../lib/verzapay';

// POST { amount, provider: 'feexpay'|'verzapay', network?, phoneNumber, otp? }
// Crée un paiement dont le succès (webhook) crédite le portefeuille au lieu
// de marquer une commande/course payée — voir finalizePayment() des 2 webhooks.
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.uid !== params.userId) return jsonError('forbidden', 403);

  const { amount, provider, network, phoneNumber, otp } = await req.json();
  if (!amount || amount < 100) return jsonError('invalid_amount', 400);

  const paymentRef = await db.collection('payments').add({
    orderId: null,
    rideId: null,
    walletUserId: params.userId,
    userId: auth.uid,
    provider,
    providerReference: null,
    status: 'pending',
    amount,
    currency: 'XOF',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  try {
    if (provider === 'feexpay') {
      const result = await feexpayRequestToPay({
        network,
        phoneNumber,
        amount,
        description: 'Dépôt portefeuille Livra',
        callbackInfo: paymentRef.id,
        otp,
      });
      await paymentRef.update({ providerReference: result.reference || result.order_id || null });
      return Response.json({ paymentId: paymentRef.id, ...result });
    } else {
      const result = await verzapayCreatePayment({
        amount,
        currency: 'XOF',
        description: 'Dépôt portefeuille Livra',
        customerName: auth.user.name,
        customerPhone: phoneNumber,
      });
      await paymentRef.update({ providerReference: result.id });
      return Response.json({ paymentId: paymentRef.id, checkoutUrl: result.checkout_url });
    }
  } catch (e) {
    await paymentRef.update({ status: 'failed' });
    return jsonError(e.message, 400);
  }
}
