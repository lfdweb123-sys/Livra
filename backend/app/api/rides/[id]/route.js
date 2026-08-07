import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { sendNotification } from '../../../../lib/fcm';
import { notifySpecificDriver } from '../../../../lib/matching';
import { creditPendingEarnings, EARNINGS_HOLD_DAYS } from '../../../../lib/wallet';
import { logOffPlatformDelivery } from '../../../../lib/offPlatform';

const DRIVER_ALLOWED = ['accepted', 'arriving', 'in_progress', 'completed'];

export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const snap = await db.collection('rides').doc(params.id).get();
  if (!snap.exists) return jsonError('not_found', 404);
  return Response.json({ id: snap.id, ...snap.data() });
}

export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { status, driverId, paymentMethod, preferredDriverId, offPlatformDriverPhone } = await req.json();
  const ref = db.collection('rides').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  const ride = snap.data();

  // Le client choisit (ou change) un chauffeur/taxi-moto précis, OU un
  // chauffeur HORS application (numéro transmis à l'admin) APRÈS la
  // création de la course — typiquement proposé sur l'écran de suivi si
  // personne n'a encore accepté après un moment d'attente.
  if ((preferredDriverId || offPlatformDriverPhone) && !status && !paymentMethod) {
    if (ride.clientId !== auth.uid) return jsonError('forbidden', 403);
    if (ride.driverId) return jsonError('already_assigned', 400);

    if (offPlatformDriverPhone) {
      await ref.update({
        offPlatformDriverPhone,
        preferredDriverId: null,
        readyForPickup: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
      await logOffPlatformDelivery({ phone: offPlatformDriverPhone, declaredBy: auth.uid, role: 'client', rideId: params.id });
      return Response.json({ ok: true });
    }

    const driverSnap = await db.collection('drivers').doc(preferredDriverId).get();
    if (!driverSnap.exists || driverSnap.data().status !== 'active' || !driverSnap.data().isOnline) {
      return jsonError('driver_unavailable', 400);
    }
    await ref.update({ preferredDriverId, updatedAt: FieldValue.serverTimestamp() });
    await notifySpecificDriver({
      driverId: preferredDriverId,
      title: 'Nouvelle course disponible',
      body: `Course ${ride.vehicleType} — ${ride.price} XOF, ${ride.distanceKm} km.`,
      type: 'new_ride',
      relatedId: params.id,
    });
    return Response.json({ ok: true });
  }

  if (paymentMethod && !status) {
    if (ride.clientId !== auth.uid) return jsonError('forbidden', 403);
    if (ride.paymentStatus !== 'pending') return jsonError('payment_already_processed', 400);

    if (paymentMethod === 'wallet') {
      const amount = ride.price ?? 0;
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
            reason: 'ride_payment',
            relatedRideId: params.id,
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

  const isClientCancel = auth.role === 'client' && ride.clientId === auth.uid && ride.status === 'pending' && status === 'cancelled';
  const isDriverMove = auth.role === 'driver' && DRIVER_ALLOWED.includes(status);
  const isAdmin = auth.role === 'admin';
  if (!(isClientCancel || isDriverMove || isAdmin)) return jsonError('forbidden', 403);

  const update = { status, updatedAt: FieldValue.serverTimestamp() };
  if (status === 'accepted' && !ride.driverId && driverId) {
    update.driverId = driverId;
    update.readyForPickup = false;
  }
  if (status === 'completed' && ride.paymentMethod === 'cash' && ride.paymentStatus !== 'paid') {
    update.paymentStatus = 'paid';
  }

  await ref.update(update);
  await sendNotification({
    userId: ride.clientId,
    title: 'Course mise à jour',
    body: `Votre course est maintenant: ${status}`,
    type: 'ride_update',
    relatedId: params.id,
  });
  if (update.paymentStatus === 'paid') {
    await sendNotification({
      userId: ride.clientId,
      title: 'Paiement confirmé',
      body: `Votre paiement en espèces de ${ride.price} XOF a été confirmé.`,
      type: 'payment_confirmed',
      relatedId: params.id,
    });
  }
  if (status === 'completed' && ride.driverId) {
    // Compteur de courses effectuées, affiché sur le profil public du
    // chauffeur/taxi-moto.
    await db.collection('drivers').doc(ride.driverId).update({ completedCount: FieldValue.increment(1) }).catch(() => {});

    // Versement du gain — bloqué EARNINGS_HOLD_DAYS jours (voir
    // lib/wallet.js). Le chauffeur/taxi-moto touche basePrice EN ENTIER
    // (le prix qu'il a fixé lui-même, hors frais de service de 5% qui
    // reste le revenu de la plateforme).
    const driverSnap = await db.collection('drivers').doc(ride.driverId).get();
    if (driverSnap.exists && ride.basePrice) {
      await creditPendingEarnings({
        userId: driverSnap.data().ownerId,
        amount: ride.basePrice,
        reason: 'ride_earnings',
        relatedRideId: params.id,
      });
      await sendNotification({
        userId: driverSnap.data().ownerId,
        title: 'Gain crédité',
        body: `${ride.basePrice} XOF ajoutés à votre portefeuille — disponibles dans ${EARNINGS_HOLD_DAYS} jours.`,
        type: 'earnings_credited',
        relatedId: params.id,
      });
    }
  }
  return Response.json({ ok: true });
}
