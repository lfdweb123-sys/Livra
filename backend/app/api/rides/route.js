import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { computeRidePrice } from '../../../lib/pricing';
import { toGeoPoint } from '../../../lib/geo';
import { notifyNearbyDrivers, notifySpecificDriver } from '../../../lib/matching';
import { logOffPlatformDelivery } from '../../../lib/offPlatform';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'client') return jsonError('forbidden', 403);

  const { pickupLocation, dropoffLocation, vehicleType, paymentMethod, preferredDriverId, offPlatformDriverPhone } = await req.json();
  if (!pickupLocation?.geopoint || !dropoffLocation?.geopoint) return jsonError('locations_required', 400);
  if (!['moto', 'voiture'].includes(vehicleType)) return jsonError('invalid_vehicleType', 400);

  // Le client peut choisir un chauffeur/taxi-moto actif précis proposé par
  // l'appli, un chauffeur HORS application (numéro transmis à l'admin), ou
  // ne rien préciser (course proposée à tous les chauffeurs à proximité).
  let validatedPreferredDriverId = null;
  let preferredDriverPricingConfig = null;
  if (preferredDriverId && !offPlatformDriverPhone) {
    const driverSnap = await db.collection('drivers').doc(preferredDriverId).get();
    if (driverSnap.exists && driverSnap.data().status === 'active' && driverSnap.data().isOnline) {
      validatedPreferredDriverId = preferredDriverId;
      preferredDriverPricingConfig = driverSnap.data().pricingConfig || null;
    }
  }

  const { price, basePrice, serviceFee, serviceFeePercent, distanceKm, etaMinutes } =
    computeRidePrice(vehicleType, pickupLocation.geopoint, dropoffLocation.geopoint, preferredDriverPricingConfig);
  const matchPosition = toGeoPoint(pickupLocation.geopoint.latitude, pickupLocation.geopoint.longitude);

  const rideRef = await db.collection('rides').add({
    clientId: auth.uid,
    driverId: null,
    preferredDriverId: validatedPreferredDriverId,
    offPlatformDriverPhone: offPlatformDriverPhone || null,
    pickupLocation,
    dropoffLocation,
    vehicleType,
    status: 'pending',
    // Un chauffeur hors application ne doit jamais apparaître dans les
    // courses disponibles pour les chauffeurs Livra.
    readyForPickup: !offPlatformDriverPhone,
    matchPosition,
    price, // total facturé au client (basePrice + serviceFee)
    basePrice,
    serviceFee,
    serviceFeePercent,
    distanceKm,
    etaMinutes,
    paymentMethod: paymentMethod || null,
    paymentStatus: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (offPlatformDriverPhone) {
    await logOffPlatformDelivery({ phone: offPlatformDriverPhone, declaredBy: auth.uid, role: 'client', rideId: rideRef.id });
  } else if (validatedPreferredDriverId) {
    await notifySpecificDriver({
      driverId: validatedPreferredDriverId,
      title: 'Nouvelle course disponible',
      body: `Course ${vehicleType} — ${price} XOF, ${distanceKm} km.`,
      type: 'new_ride',
      relatedId: rideRef.id,
    });
  } else {
    await notifyNearbyDrivers({
      pickupLat: pickupLocation.geopoint.latitude,
      pickupLng: pickupLocation.geopoint.longitude,
      vehicleTypeFilter: [vehicleType],
      title: 'Nouvelle course disponible',
      body: `Course ${vehicleType} — ${price} XOF, ${distanceKm} km.`,
      type: 'new_ride',
      relatedId: rideRef.id,
    });
  }

  return Response.json({ id: rideRef.id, price, basePrice, serviceFee, serviceFeePercent, distanceKm, etaMinutes });
}

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status');
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);

  let query = db.collection('rides');
  if (auth.role === 'client') query = query.where('clientId', '==', auth.uid);
  else if (auth.role === 'driver') {
    const driverSnap = await db.collection('drivers').where('ownerId', '==', auth.uid).limit(1).get();
    if (driverSnap.empty) return Response.json({ items: [] });
    query = query.where('driverId', '==', driverSnap.docs[0].id);
  } else if (auth.role !== 'admin') return jsonError('forbidden', 403);

  if (status) query = query.where('status', '==', status);
  query = query.orderBy('createdAt', 'desc').limit(limit);
  try {
    const snap = await query.get();
    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[RIDES_GET_QUERY_ERROR]', { role: auth.role, uid: auth.uid, status, message: e.message, code: e.code });
    return jsonError('rides_query_failed', 500);
  }
}
