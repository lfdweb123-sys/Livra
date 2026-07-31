import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { computeRidePrice } from '../../../lib/pricing';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'client') return jsonError('forbidden', 403);

  const { pickupLocation, dropoffLocation, vehicleType, paymentMethod } = await req.json();
  if (!pickupLocation?.geopoint || !dropoffLocation?.geopoint) return jsonError('locations_required', 400);
  if (!['moto', 'voiture'].includes(vehicleType)) return jsonError('invalid_vehicleType', 400);

  const { price, distanceKm, etaMinutes } = computeRidePrice(vehicleType, pickupLocation.geopoint, dropoffLocation.geopoint);

  const rideRef = await db.collection('rides').add({
    clientId: auth.uid,
    driverId: null,
    pickupLocation,
    dropoffLocation,
    vehicleType,
    status: 'pending',
    price,
    distanceKm,
    etaMinutes,
    paymentMethod: paymentMethod || null,
    paymentStatus: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return Response.json({ id: rideRef.id, price, distanceKm, etaMinutes });
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
