import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';
import { sendTransactionalEmail, orderDeliveredEmail } from '../../../../lib/brevo';
import { notifyNearbyDrivers } from '../../../../lib/matching';

const VENDOR_ALLOWED = ['accepted', 'preparing', 'picked_up'];
const DRIVER_ALLOWED = ['picked_up', 'delivering', 'delivered'];

export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const snap = await db.collection('orders').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

// PATCH { status?, driverId?, paymentMethod? } — transition contrôlée selon le rôle
export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { status, driverId, paymentMethod } = await req.json();
  const ref = db.collection('orders').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const order = snap.data();

  // Le client choisit son moyen de paiement (espèces à la livraison, ou
  // portefeuille Livra débité immédiatement) — uniquement avant tout
  // paiement engagé.
  if (paymentMethod && !status) {
    if (order.clientId !== auth.uid) return jsonError('forbidden', 403);
    if (order.paymentStatus !== 'pending') return jsonError('payment_already_processed', 400);

    if (paymentMethod === 'wallet') {
      const amount = order.priceBreakdown?.total ?? 0;
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
            reason: 'order_payment',
            relatedOrderId: params.id,
            createdAt: FieldValue.serverTimestamp(),
          });
          tx.update(ref, { paymentMethod: 'wallet', paymentStatus: 'paid', updatedAt: FieldValue.serverTimestamp() });
        });
      } catch (e) {
        if (e.message === 'insufficient_balance') return jsonError('insufficient_balance', 400);
        throw e;
      }
      await sendNotification({
        userId: auth.uid,
        title: 'Paiement confirmé',
        body: `${amount} XOF ont été débités de votre portefeuille Livra.`,
        type: 'payment_confirmed',
        relatedId: params.id,
      });
      return Response.json({ ok: true });
    }

    await ref.update({ paymentMethod, updatedAt: FieldValue.serverTimestamp() });
    return Response.json({ ok: true });
  }

  const isClientCancel = auth.role === 'client' && order.clientId === auth.uid && order.status === 'pending' && status === 'cancelled';
  const isVendorMove = auth.role === 'vendor' && VENDOR_ALLOWED.includes(status);
  const isDriverMove = auth.role === 'driver' && DRIVER_ALLOWED.includes(status);
  const isAdmin = auth.role === 'admin';

  if (!(isClientCancel || isVendorMove || isDriverMove || isAdmin)) return jsonError('forbidden', 403);

  const update = {
    status,
    updatedAt: FieldValue.serverTimestamp(),
    statusHistory: FieldValue.arrayUnion({ status, at: new Date().toISOString(), by: auth.uid }),
  };
  // un livreur qui accepte une commande "picked_up" venant de vendeur s'auto-assigne s'il n'y a pas encore de driverId
  const driverClaiming = status === 'picked_up' && !order.driverId && driverId;
  if (driverClaiming) {
    update.driverId = driverId;
    update.readyForPickup = false; // claimé, plus visible pour les autres livreurs
  } else if (auth.role === 'vendor' && status === 'picked_up') {
    // le vendeur marque le plat prêt : devient visible pour les livreurs à proximité
    update.readyForPickup = true;
  }
  // paiement espèces : encaissé par le livreur à la livraison, confirmé automatiquement
  if (status === 'delivered' && order.paymentMethod === 'cash' && order.paymentStatus !== 'paid') {
    update.paymentStatus = 'paid';
  }

  await ref.update(update);

  if (update.readyForPickup === true && auth.role === 'vendor') {
    const pickup = order.matchPosition?.geopoint;
    if (pickup) {
      await notifyNearbyDrivers({
        pickupLat: pickup.latitude,
        pickupLng: pickup.longitude,
        title: 'Nouvelle livraison disponible',
        body: `Une commande prête à récupérer, ${order.priceBreakdown?.deliveryFee ?? ''} XOF de frais.`,
        type: 'new_delivery',
        relatedId: params.id,
      });
    }
  }

  await sendNotification({
    userId: order.clientId,
    title: 'Commande mise à jour',
    body: `Votre commande est maintenant: ${status}`,
    type: 'order_update',
    relatedId: params.id,
  });

  if (update.paymentStatus === 'paid') {
    await sendNotification({
      userId: order.clientId,
      title: 'Paiement confirmé',
      body: `Votre paiement en espèces de ${order.priceBreakdown?.total ?? ''} XOF a été confirmé.`,
      type: 'payment_confirmed',
      relatedId: params.id,
    });
  }

  if (status === 'delivered') {
    const clientSnap = await db.collection('users').doc(order.clientId).get();
    if (clientSnap.exists && clientSnap.data().email) {
      const { subject, htmlContent } = orderDeliveredEmail(params.id, order.priceBreakdown?.total);
      await sendTransactionalEmail({ to: clientSnap.data().email, toName: clientSnap.data().name, subject, htmlContent });
    }
  }

  return Response.json({ ok: true });
}
