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
