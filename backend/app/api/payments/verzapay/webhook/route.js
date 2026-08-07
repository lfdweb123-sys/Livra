import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { sendNotification } from '../../../../../lib/fcm';
import { notifyOrderPaid } from '../../../../../lib/matching';

// Webhook Verzapay confirmé: payload plat, pas de wrapper "data", pas de signature
// cryptographique (pattern confirmé empiriquement sur les autres intégrations Verzapay).
export async function POST(req) {
  const event = await req.json();

  const paymentSnap = await db.collection('payments').where('providerReference', '==', event.id).limit(1).get();
  if (paymentSnap.empty) return Response.json({ received: true });
  const paymentDoc = paymentSnap.docs[0];
  const payment = paymentDoc.data();

  if (event.type === 'payment.completed') {
    await paymentDoc.ref.update({ status: 'successful', updatedAt: FieldValue.serverTimestamp() });

    if (payment.adCampaignId) {
      const campaignRef = db.collection('ad_campaigns').doc(payment.adCampaignId);
      const campaignSnap = await campaignRef.get();
      if (campaignSnap.exists) {
        const startAt = new Date();
        const endAt = new Date(startAt.getTime() + campaignSnap.data().days * 24 * 60 * 60 * 1000);
        await campaignRef.update({ status: 'active', startAt, endAt });
        await sendNotification({
          userId: payment.userId,
          title: 'Publicité lancée',
          body: `Votre campagne pour "${campaignSnap.data().productName}" est active.`,
          type: 'ad_activated',
          relatedId: payment.adCampaignId,
        });
      }
    } else if (payment.boostId) {
      const boostRef = db.collection('profile_boosts').doc(payment.boostId);
      const boostSnap = await boostRef.get();
      if (boostSnap.exists) {
        const startAt = new Date();
        const endAt = new Date(startAt.getTime() + boostSnap.data().days * 24 * 60 * 60 * 1000);
        await boostRef.update({ status: 'active', startAt, endAt });
        await sendNotification({
          userId: payment.userId,
          title: 'Boost de profil actif',
          body: 'Votre profil apparaît maintenant en priorité.',
          type: 'boost_activated',
          relatedId: payment.boostId,
        });
      }
    } else if (payment.walletUserId) {
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
    } else {
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
  } else if (event.type === 'payment.failed') {
    await paymentDoc.ref.update({ status: 'failed', updatedAt: FieldValue.serverTimestamp() });
  } else if (event.type === 'payout.completed' || event.type === 'payout.failed') {
    // décaissements retrait wallet — voir /api/wallet/[userId]/withdraw
    await paymentDoc.ref.update({
      status: event.type === 'payout.completed' ? 'successful' : 'failed',
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  return Response.json({ received: true });
}
