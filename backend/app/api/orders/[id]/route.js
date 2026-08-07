import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';
import { sendTransactionalEmail, orderDeliveredEmail } from '../../../../lib/brevo';
import { notifyNearbyDrivers, notifyOrderPaid, notifySpecificDriver } from '../../../../lib/matching';
import { creditPendingEarnings, EARNINGS_HOLD_DAYS } from '../../../../lib/wallet';
import { logOffPlatformDelivery } from '../../../../lib/offPlatform';

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

  const { status, driverId, paymentMethod, preferredDriverId, offPlatformDriverPhone } = await req.json();
  const ref = db.collection('orders').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const order = snap.data();

  // Le client choisit (ou change) un livreur précis, OU un livreur HORS
  // application (numéro transmis à l'admin) APRÈS la création du colis —
  // typiquement proposé sur l'écran de suivi si personne n'a encore
  // accepté après un moment d'attente. Uniquement pour les colis (type
  // !== 'nourriture'): pour une commande nourriture, c'est le vendeur qui
  // choisit le livreur en marquant le plat prêt.
  if ((preferredDriverId || offPlatformDriverPhone) && !status && !paymentMethod) {
    if (order.clientId !== auth.uid) return jsonError('forbidden', 403);
    // Le vendeur choisit normalement le livreur pour une commande nourriture
    // au moment de marquer le plat prêt — mais si personne n'a encore été
    // notifié (le plat n'est pas encore "readyForPickup"), le client peut
    // débloquer la situation lui-même plutôt que d'attendre indéfiniment.
    if (order.type === 'nourriture' && order.readyForPickup) return jsonError('vendor_assigns_driver', 400);
    if (order.driverId) return jsonError('already_assigned', 400);

    if (offPlatformDriverPhone) {
      await ref.update({ offPlatformDriverPhone, preferredDriverId: null, updatedAt: FieldValue.serverTimestamp() });
      await logOffPlatformDelivery({ phone: offPlatformDriverPhone, declaredBy: auth.uid, role: 'client', orderId: params.id });
      return Response.json({ ok: true });
    }

    const driverSnap = await db.collection('drivers').doc(preferredDriverId).get();
    if (!driverSnap.exists || driverSnap.data().status !== 'active' || !driverSnap.data().isOnline) {
      return jsonError('driver_unavailable', 400);
    }
    await ref.update({ preferredDriverId, updatedAt: FieldValue.serverTimestamp() });
    await notifySpecificDriver({
      driverId: preferredDriverId,
      title: 'Nouvelle livraison disponible',
      body: `Colis à récupérer, ${order.priceBreakdown?.deliveryFee ?? 0} XOF de frais.`,
      type: 'new_delivery',
      relatedId: params.id,
    });
    return Response.json({ ok: true });
  }

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
      try {
        await notifyOrderPaid(params.id);
      } catch (e) {
        console.error('[NOTIFY_ORDER_PAID_ERROR]', params.id, e.message);
      }
      return Response.json({ ok: true });
    }

    await ref.update({ paymentMethod, updatedAt: FieldValue.serverTimestamp() });
    if (paymentMethod === 'cash') {
      // Espèces à la livraison : il n'y aura pas d'autre événement de
      // "paiement confirmé" avant la livraison elle-même, donc c'est ici
      // qu'on informe le vendeur/les livreurs pour ne pas les faire
      // attendre indéfiniment un paiement qui n'arrivera qu'à la fin.
      try {
        await notifyOrderPaid(params.id);
      } catch (e) {
        console.error('[NOTIFY_ORDER_PAID_ERROR]', params.id, e.message);
      }
    }
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
    // Le vendeur peut choisir un livreur actif précis (proposé par
    // l'appli), un livreur HORS application (numéro transmis à l'admin),
    // ou ne rien préciser et laisser l'appli proposer la commande à tous
    // les livreurs à proximité.
    if (offPlatformDriverPhone) {
      // Livreur hors application choisi : n'apparaît plus dans les
      // commandes disponibles pour les livreurs Livra, il est déjà pris
      // en charge en dehors de la plateforme.
      update.readyForPickup = false;
      update.offPlatformDriverPhone = offPlatformDriverPhone;
      update.preferredDriverId = null;
    } else if (preferredDriverId) {
      const driverSnap = await db.collection('drivers').doc(preferredDriverId).get();
      if (driverSnap.exists && driverSnap.data().status === 'active' && driverSnap.data().isOnline) {
        update.preferredDriverId = preferredDriverId;
      }
    }
  }
  // paiement espèces : encaissé par le livreur à la livraison, confirmé automatiquement
  if (status === 'delivered' && order.paymentMethod === 'cash' && order.paymentStatus !== 'paid') {
    update.paymentStatus = 'paid';
  }

  await ref.update(update);
  if (update.offPlatformDriverPhone) {
    await logOffPlatformDelivery({ phone: update.offPlatformDriverPhone, declaredBy: auth.uid, role: 'vendor', orderId: params.id });
  }

  if (update.readyForPickup === true && auth.role === 'vendor') {
    if (update.preferredDriverId) {
      await notifySpecificDriver({
        driverId: update.preferredDriverId,
        title: 'Nouvelle livraison disponible',
        body: `Une commande prête à récupérer, ${order.priceBreakdown?.deliveryFee ?? ''} XOF de frais.`,
        type: 'new_delivery',
        relatedId: params.id,
      });
    } else {
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
    // Compteur de services rendus, affiché sur les profils publics
    // (vendeur/restaurant/boutique et livreur/chauffeur).
    if (order.vendorId) {
      await db.collection('vendors').doc(order.vendorId).update({ completedCount: FieldValue.increment(1) }).catch(() => {});
    }
    if (order.driverId) {
      await db.collection('drivers').doc(order.driverId).update({ completedCount: FieldValue.increment(1) }).catch(() => {});
    }

    // Versement des gains — bloqué EARNINGS_HOLD_DAYS jours avant d'être
    // retirable (voir lib/wallet.js), le temps qu'une éventuelle
    // réclamation client puisse être traitée. Le vendeur touche le
    // sous-total moins sa commission (déjà configurée par l'admin), le
    // livreur touche le frais de livraison EN ENTIER (c'est lui qui
    // fixe ce montant — voir configuration tarifaire livreur).
    if (order.vendorId && order.priceBreakdown?.subtotal) {
      const vendorSnap = await db.collection('vendors').doc(order.vendorId).get();
      if (vendorSnap.exists) {
        const commissionPercent = vendorSnap.data().commission || 0;
        const vendorDue = Math.round(order.priceBreakdown.subtotal * (1 - commissionPercent / 100));
        if (vendorDue > 0) {
          await creditPendingEarnings({
            userId: vendorSnap.data().ownerId,
            amount: vendorDue,
            reason: 'order_earnings',
            relatedOrderId: params.id,
          });
        }
      }
    }
    if (order.driverId && order.priceBreakdown?.deliveryFee) {
      const driverSnap = await db.collection('drivers').doc(order.driverId).get();
      if (driverSnap.exists) {
        await creditPendingEarnings({
          userId: driverSnap.data().ownerId,
          amount: order.priceBreakdown.deliveryFee,
          reason: 'delivery_earnings',
          relatedOrderId: params.id,
        });
        await sendNotification({
          userId: driverSnap.data().ownerId,
          title: 'Gain crédité',
          body: `${order.priceBreakdown.deliveryFee} XOF ajoutés à votre portefeuille — disponibles dans ${EARNINGS_HOLD_DAYS} jours.`,
          type: 'earnings_credited',
          relatedId: params.id,
        });
      }
    }
  }

  return Response.json({ ok: true });
}
