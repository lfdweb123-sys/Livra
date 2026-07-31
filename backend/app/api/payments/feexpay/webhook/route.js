import { db, FieldValue } from '../../../../../lib/firebaseAdmin';

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
  const targetCollection = payment.orderId ? 'orders' : 'rides';
  const targetId = payment.orderId || payment.rideId;
  await db.collection(targetCollection).doc(targetId).update({
    paymentStatus: 'paid',
    updatedAt: FieldValue.serverTimestamp(),
  });
}
