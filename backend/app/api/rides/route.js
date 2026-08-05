import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { computeRidePrice } from '../../../lib/pricing';
import { toGeoPoint } from '../../../lib/geo';
import { notifyNearbyDrivers } from '../../../lib/matching';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'client') return jsonError('forbidden', 403);

  const { pickupLocation, dropoffLocation, vehicleType, paymentMethod } = await req.json();
  if (!pickupLocation?.geopoint || !dropoffLocation?.geopoint) return jsonError('locations_required', 400);
  if (!['moto', 'voiture'].includes(vehicleType)) return jsonError('invalid_vehicleType', 400);

  const { price, basePrice, serviceFee, serviceFeePercent, distanceKm, etaMinutes } =
    computeRidePrice(vehicleType, pickupLocation.geopoint, dropoffLocation.geopoint);
  const matchPosition = toGeoPoint(pickupLocation.geopoint.latitude, pickupLocation.geopoint.longitude);

  const rideRef = await db.collection('rides').add({
    clientId: auth.uid,
    driverId: null,
    pickupLocation,
    dropoffLocation,
    vehicleType,
    status: 'pending',
    readyForPickup: true, // une course est disponible immédiatement, pas d'étape de préparation
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

  await notifyNearbyDrivers({
    pickupLat: pickupLocation.geopoint.latitude,
    pickupLng: pickupLocation.geopoint.longitude,
    vehicleTypeFilter: [vehicleType],
    title: 'Nouvelle course disponible',
    body: `Course ${vehicleType} — ${price} XOF, ${distanceKm} km.`,
    type: 'new_ride',
    relatedId: rideRef.id,
  });

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
  const snap = await query.get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}
