import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { sendNotification } from '../../../../../lib/fcm';

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
}
