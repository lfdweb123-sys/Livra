import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { sendNotification } from '../../../../../lib/fcm';

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

    if (payment.walletUserId) {
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
