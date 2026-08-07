import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { sendNotification } from '../../../../../lib/fcm';
import { notifyOrderPaid } from '../../../../../lib/matching';

// FeexPay callback_info == notre paymentId (pattern déjà utilisé sur les autres projets)
export async function POST(req) {
  const event = await req.json();
  const paymentId = event.callback_info;
  if (!paymentId) return Response.json({ received: true });

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return Response.json({ received: true });
  const payment = paymentSnap.data();

  const success = event.status === 'SUCCESSFUL' || event.status === 'successful';
  const failed = event.status === 'FAILED' || event.status === 'failed';

  await paymentRef.update({
    status: success ? 'successful' : failed ? 'failed' : 'pending',
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (success) await finalizePayment(payment);
  return Response.json({ received: true });
}

async function finalizePayment(payment) {
  if (payment.adCampaignId) {
    const startAt = new Date();
    const endAt = new Date();
    const campaignRef = db.collection('ad_campaigns').doc(payment.adCampaignId);
    const campaignSnap = await campaignRef.get();
    if (campaignSnap.exists) {
      endAt.setTime(startAt.getTime() + campaignSnap.data().days * 24 * 60 * 60 * 1000);
      await campaignRef.update({ status: 'active', startAt, endAt });
      await sendNotification({
        userId: payment.userId,
        title: 'Publicité lancée',
        body: `Votre campagne pour "${campaignSnap.data().productName}" est active.`,
        type: 'ad_activated',
        relatedId: payment.adCampaignId,
      });
    }
    return;
  }

  if (payment.boostId) {
    const startAt = new Date();
    const endAt = new Date();
    const boostRef = db.collection('profile_boosts').doc(payment.boostId);
    const boostSnap = await boostRef.get();
    if (boostSnap.exists) {
      endAt.setTime(startAt.getTime() + boostSnap.data().days * 24 * 60 * 60 * 1000);
      await boostRef.update({ status: 'active', startAt, endAt });
      await sendNotification({
        userId: payment.userId,
        title: 'Boost de profil actif',
        body: 'Votre profil apparaît maintenant en priorité.',
        type: 'boost_activated',
        relatedId: payment.boostId,
      });
    }
    return;
  }

  if (payment.walletUserId) {
    // Dépôt sur le portefeuille Livra
    const walletRef = db.collection('wallets').doc(payment.walletUserId);
    await walletRef.set(
      { balance: FieldValue.increment(payment.amount), updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    await walletRef.collection('transactions').add({
      type: 'credit',
      amount: payment.amount,
      reason: 'wallet_deposit',
      createdAt: FieldValue.serverTimestamp(),
    });
    await sendNotification({
      userId: payment.walletUserId,
      title: 'Dépôt confirmé',
      body: `${payment.amount} XOF ont été ajoutés à votre portefeuille Livra.`,
      type: 'wallet_deposit',
    });
    return;
  }

  const targetCollection = payment.orderId ? 'orders' : 'rides';
  const targetId = payment.orderId || payment.rideId;
  const targetSnap = await db.collection(targetCollection).doc(targetId).get();
  await db.collection(targetCollection).doc(targetId).update({
    paymentStatus: 'paid',
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (targetSnap.exists) {
    await sendNotification({
      userId: targetSnap.data().clientId,
      title: 'Paiement confirmé',
      body: `Votre paiement de ${payment.amount} XOF a bien été reçu.`,
      type: 'payment_confirmed',
      relatedId: targetId,
    });
  }
  if (payment.orderId) {
    try {
      await notifyOrderPaid(payment.orderId);
    } catch (e) {
      console.error('[NOTIFY_ORDER_PAID_ERROR]', payment.orderId, e.message);
    }
  }
}
