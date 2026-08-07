// Recherche + notification des livreurs disponibles à proximité, et du
// vendeur concerné — appelé à la création d'une commande/course pour que
// les intéressés soient notifiés (push FCM) même app fermée, sans attendre
// qu'ils aient l'app ouverte avec le listener Firestore actif.
import { db } from './firebaseAdmin';
import { distanceKm } from './geo';
import { sendNotification } from './fcm';
import { sendTransactionalEmail } from './brevo';

const MATCH_RADIUS_KM = 6;

/**
 * Notifie les livreurs actifs+en ligne dans un rayon autour du point de
 * collecte. Ne fait qu'une lecture simple (drivers actifs en ligne) — à ce
 * stade de volume, pas besoin de requête géo complexe côté serveur, le
 * filtrage par distance se fait en mémoire sur un nombre de lignes limité.
 */
export async function notifyNearbyDrivers({ pickupLat, pickupLng, vehicleTypeFilter, title, body, type, relatedId }) {
  const snap = await db
    .collection('drivers')
    .where('status', '==', 'active')
    .where('isOnline', '==', true)
    .limit(200)
    .get();

  const notified = [];
  for (const doc of snap.docs) {
    const driver = doc.data();
    if (vehicleTypeFilter && vehicleTypeFilter.length && !vehicleTypeFilter.includes(driver.vehicleType)) continue;
    const pos = driver.position?.geopoint;
    if (!pos) continue;
    const dist = distanceKm({ latitude: pickupLat, longitude: pickupLng }, pos);
    if (dist > MATCH_RADIUS_KM) continue;
    await sendNotification({ userId: driver.ownerId, title, body, type, relatedId });
    try {
      const userSnap = await db.collection('users').doc(driver.ownerId).get();
      const email = userSnap.exists ? userSnap.data().email : null;
      if (email) {
        await sendTransactionalEmail({
          to: email,
          toName: userSnap.data().name,
          subject: title,
          htmlContent: `<p>${body}</p><p>Ouvrez l'application Livra pour l'accepter.</p>`,
        });
      }
    } catch (e) {
      console.error('[NOTIFY_DRIVER_EMAIL_ERROR]', e.message);
    }
    notified.push(doc.id);
  }
  return notified;
}

/**
 * Notifie UN SEUL livreur/chauffeur choisi explicitement par le client ou
 * le vendeur (au lieu du broadcast à tous les livreurs à proximité) — voir
 * le champ `preferredDriverId` sur orders/rides.
 */
export async function notifySpecificDriver({ driverId, title, body, type, relatedId }) {
  const snap = await db.collection('drivers').doc(driverId).get();
  if (!snap.exists) return false;
  const driver = snap.data();
  await sendNotification({ userId: driver.ownerId, title, body, type, relatedId });
  try {
    const userSnap = await db.collection('users').doc(driver.ownerId).get();
    const email = userSnap.exists ? userSnap.data().email : null;
    if (email) {
      await sendTransactionalEmail({
        to: email,
        toName: userSnap.data().name,
        subject: title,
        htmlContent: `<p>${body}</p><p>Ouvrez l'application Livra pour l'accepter.</p>`,
      });
    }
  } catch (e) {
    console.error('[NOTIFY_SPECIFIC_DRIVER_EMAIL_ERROR]', e.message);
  }
  return true;
}

export async function notifyVendor({ vendorOwnerId, title, body, type, relatedId }) {
  await sendNotification({ userId: vendorOwnerId, title, body, type, relatedId });
  try {
    const userSnap = await db.collection('users').doc(vendorOwnerId).get();
    const email = userSnap.exists ? userSnap.data().email : null;
    if (email) {
      await sendTransactionalEmail({
        to: email,
        toName: userSnap.data().name,
        subject: title,
        htmlContent: `<p>${body}</p><p>Ouvrez l'application Livra pour la traiter.</p>`,
      });
    }
  } catch (e) {
    console.error('[NOTIFY_VENDOR_EMAIL_ERROR]', e.message);
  }
}

/**
 * Notifie le vendeur (nourriture) ou les livreurs à proximité (colis) —
 * UNIQUEMENT une fois la commande payée (portefeuille : immédiat ; Mobile
 * Money/carte : depuis le webhook de paiement ; espèces : au choix du
 * moyen de paiement, puisqu'il n'y a pas d'autre étape de confirmation
 * possible avant la livraison). Le détail exact des articles commandés est
 * inclus dans le push ET l'email, comme demandé.
 */
export async function notifyOrderPaid(orderId) {
  const orderSnap = await db.collection('orders').doc(orderId).get();
  if (!orderSnap.exists) return;
  const order = orderSnap.data();

  const itemsSummary = (order.items || [])
    .map((i) => `${i.quantity || 1}x ${i.name || 'article'}`)
    .join(', ');

  if (order.type === 'nourriture' && order.vendorId) {
    const vendorSnap = await db.collection('vendors').doc(order.vendorId).get();
    if (vendorSnap.exists) {
      await notifyVendor({
        vendorOwnerId: vendorSnap.data().ownerId,
        title: 'Nouvelle commande payée',
        body: `${itemsSummary || 'Commande'} — ${order.priceBreakdown?.subtotal ?? 0} XOF. À préparer dès maintenant.`,
        type: 'new_order',
        relatedId: orderId,
      });
    }
  } else if (order.type === 'colis') {
    const pickup = order.pickupAddress?.geopoint;
    if (pickup) {
      // Adresse de collecte incluse dès la diffusion (utile pour décider
      // d'accepter) — pas les numéros de téléphone à ce stade, voir
      // commentaire détaillé dans orders/[id]/route.js.
      const pickupLabel = order.pickupAddress?.label ? ` — ${order.pickupAddress.label}` : '';
      if (order.preferredDriverId) {
        // Le client a choisi un livreur précis pour ce colis: on ne
        // notifie QUE lui, pas de broadcast.
        await notifySpecificDriver({
          driverId: order.preferredDriverId,
          title: 'Nouvelle livraison disponible',
          body: `Colis à récupérer${pickupLabel}, ${order.priceBreakdown?.deliveryFee ?? 0} XOF de frais.`,
          type: 'new_delivery',
          relatedId: orderId,
        });
      } else {
        await notifyNearbyDrivers({
          pickupLat: pickup.latitude,
          pickupLng: pickup.longitude,
          title: 'Nouvelle livraison disponible',
          body: `Colis à récupérer${pickupLabel}, ${order.priceBreakdown?.deliveryFee ?? 0} XOF de frais.`,
          type: 'new_delivery',
          relatedId: orderId,
        });
      }
    }
  }
}
