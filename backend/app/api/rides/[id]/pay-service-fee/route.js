import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { feexpayRequestToPay } from '../../../../../lib/feexpay';
import { verzapayCreatePayment, resolveCustomerPhone } from '../../../../../lib/verzapay';

// POST { provider: 'wallet'|'feexpay'|'verzapay', network?, phoneNumber?, otp? }
// Même principe que pour les commandes — voir orders/[id]/pay-service-fee.
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const ref = db.collection('rides').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const ride = snap.data();
  if (ride.clientId !== auth.uid) return jsonError('forbidden', 403);
  if (ride.serviceFeePaid) return jsonError('already_paid', 400);

  const amount = ride.serviceFee;
  if (!amount || amount <= 0) return jsonError('no_service_fee_due', 400);

  const { provider, network, phoneNumber, otp } = await req.json();

  if (provider === 'wallet') {
    const walletRef = db.collection('wallets').doc(auth.uid);
    try {
      await db.runTransaction(async (tx) => {
        const walletSnap = await tx.get(walletRef);
        const balance = walletSnap.exists ? walletSnap.data().balance || 0 : 0;
        if (balance < amount) throw new Error('insufficient_balance');
        tx.set(walletRef, { balance: FieldValue.increment(-amount), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(walletRef.collection('transactions').doc(), {
          type: 'debit',
          amount,
          reason: 'service_fee_cash_ride',
          relatedRideId: params.id,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.update(ref, {
          serviceFeePaid: true,
          serviceFeePaidAt: FieldValue.serverTimestamp(),
          paymentMethod: 'cash',
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e.message === 'insufficient_balance') return jsonError('insufficient_balance', 400);
      throw e;
    }
    return Response.json({ ok: true, serviceFeePaid: true });
  }

  const paymentRef = await db.collection('payments').add({
    orderId: null,
    rideId: null,
    serviceFeeForRideId: params.id,
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
        description: 'Frais de service Livra (course espèces)',
        callbackInfo: paymentRef.id,
        otp,
      });
      await paymentRef.update({ providerReference: result.reference || result.order_id || null });
      return Response.json({ paymentId: paymentRef.id, ...result });
    } else if (provider === 'verzapay') {
      const customerPhone = resolveCustomerPhone(phoneNumber, auth.user.phone);
      if (!customerPhone) {
        await paymentRef.update({ status: 'failed' });
        return jsonError('phone_required', 400);
      }
      const result = await verzapayCreatePayment({
        amount,
        currency: 'XOF',
        description: 'Frais de service Livra (course espèces)',
        customerName: auth.user.name,
        customerPhone,
      });
      await paymentRef.update({ providerReference: result.id });
      return Response.json({ paymentId: paymentRef.id, checkoutUrl: result.checkout_url });
    }
    return jsonError('invalid_provider', 400);
  } catch (e) {
    await paymentRef.update({ status: 'failed' });
    return jsonError(e.message, 400);
  }
}
