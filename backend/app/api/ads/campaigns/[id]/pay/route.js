import { db, FieldValue } from '../../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../../lib/auth';
import { feexpayRequestToPay } from '../../../../../../lib/feexpay';
import { verzapayCreatePayment, resolveCustomerPhone } from '../../../../../../lib/verzapay';

// POST { provider: 'feexpay'|'verzapay'|'wallet', network?, phoneNumber?, otp? }
// Le paiement suit exactement le même pattern que le dépôt portefeuille
// (payment doc avec un champ dédié, ici adCampaignId) — voir les 2 webhooks
// paiement pour l'activation de la campagne une fois payée.
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const campaignRef = db.collection('ad_campaigns').doc(params.id);
  const campaignSnap = await campaignRef.get();
  if (!campaignSnap.exists) return jsonError('not_found', 404);
  const campaign = campaignSnap.data();

  const vendorSnap = await db.collection('vendors').doc(campaign.vendorId).get();
  if (!vendorSnap.exists || vendorSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);
  if (campaign.status !== 'pending_payment') return jsonError('already_processed', 400);

  const { provider, network, phoneNumber, otp } = await req.json();

  if (provider === 'wallet') {
    const walletRef = db.collection('wallets').doc(auth.uid);
    try {
      await db.runTransaction(async (tx) => {
        const walletSnap = await tx.get(walletRef);
        const balance = walletSnap.exists ? walletSnap.data().balance || 0 : 0;
        if (balance < campaign.pricePaid) throw new Error('insufficient_balance');
        tx.set(walletRef, { balance: FieldValue.increment(-campaign.pricePaid), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(walletRef.collection('transactions').doc(), {
          type: 'debit',
          amount: campaign.pricePaid,
          reason: 'ad_campaign',
          relatedCampaignId: params.id,
          createdAt: FieldValue.serverTimestamp(),
        });
        const startAt = new Date();
        const endAt = new Date(startAt.getTime() + campaign.days * 24 * 60 * 60 * 1000);
        tx.update(campaignRef, { status: 'active', startAt, endAt });
      });
    } catch (e) {
      if (e.message === 'insufficient_balance') return jsonError('insufficient_balance', 400);
      throw e;
    }
    return Response.json({ ok: true, activated: true });
  }

  const paymentRef = await db.collection('payments').add({
    orderId: null,
    rideId: null,
    adCampaignId: params.id,
    userId: auth.uid,
    provider,
    providerReference: null,
    status: 'pending',
    amount: campaign.pricePaid,
    currency: 'XOF',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  try {
    if (provider === 'feexpay') {
      const result = await feexpayRequestToPay({
        network,
        phoneNumber,
        amount: campaign.pricePaid,
        description: `Pub — ${campaign.productName.slice(0, 30)}`,
        callbackInfo: paymentRef.id,
        otp,
      });
      await paymentRef.update({ providerReference: result.reference || result.order_id || null });
      return Response.json({ paymentId: paymentRef.id, ...result });
    } else {
      const customerPhone = resolveCustomerPhone(phoneNumber, auth.user.phone);
      if (!customerPhone) {
        await paymentRef.update({ status: 'failed' });
        return jsonError('phone_required', 400);
      }
      const result = await verzapayCreatePayment({
        amount: campaign.pricePaid,
        currency: 'XOF',
        description: `Pub — ${campaign.productName.slice(0, 30)}`,
        customerName: auth.user.name,
        customerPhone,
      });
      await paymentRef.update({ providerReference: result.id });
      return Response.json({ paymentId: paymentRef.id, checkoutUrl: result.checkout_url });
    }
  } catch (e) {
    await paymentRef.update({ status: 'failed' });
    return jsonError(e.message, 400);
  }
}
