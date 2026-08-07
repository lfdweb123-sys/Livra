import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { feexpayRequestToPay } from '../../../../../lib/feexpay';
import { verzapayCreatePayment, resolveCustomerPhone } from '../../../../../lib/verzapay';
import { notifyOrderPaid } from '../../../../../lib/matching';

// POST { provider: 'wallet'|'feexpay'|'verzapay', network?, phoneNumber?, otp? }
//
// Pour une commande réglée en espèces à la livraison, Livra ne voit jamais
// passer d'argent — le client paie le livreur/vendeur directement en main
// propre. Sans ce paiement séparé, les frais de service de 5% ne seraient
// donc JAMAIS perçus sur ces commandes. Le client doit régler les frais de
// service (uniquement, pas le montant total) AVANT que l'espèces soit
// acceptée comme moyen de paiement — voir la vérification dans
// PATCH /api/orders/[id] (paymentMethod: 'cash' refusé tant que
// serviceFeePaid n'est pas true).
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const ref = db.collection('orders').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const order = snap.data();
  if (order.clientId !== auth.uid) return jsonError('forbidden', 403);
  if (order.serviceFeePaid) return jsonError('already_paid', 400);

  const amount = order.priceBreakdown?.serviceFee;
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
          reason: 'service_fee_cash_order',
          relatedOrderId: params.id,
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
    // Espèces à la livraison : il n'y aura pas d'autre événement de
    // "paiement confirmé" avant la livraison elle-même (le reste est réglé
    // en main propre) — on informe donc le vendeur/les livreurs dès
    // maintenant que les frais de service sont réglés et que la commande
    // peut être traitée normalement.
    try {
      await notifyOrderPaid(params.id);
    } catch (e) {
      console.error('[NOTIFY_ORDER_PAID_ERROR]', params.id, e.message);
    }
    return Response.json({ ok: true, serviceFeePaid: true });
  }

  const paymentRef = await db.collection('payments').add({
    orderId: null,
    rideId: null,
    serviceFeeForOrderId: params.id,
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
        description: 'Frais de service Livra (commande espèces)',
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
        description: 'Frais de service Livra (commande espèces)',
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
