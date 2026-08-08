import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { toGeoPoint } from '../../../lib/geo';
import { logActivity } from '../../../lib/activityLog';
import { notifyAdminByEmail } from '../../../lib/adminNotify';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const existing = await db.collection('drivers').where('ownerId', '==', auth.uid).limit(1).get();
  if (!existing.empty) return jsonError('already_applied', 400);

  const existingVendor = await db.collection('vendors').where('ownerId', '==', auth.uid).limit(1).get();
  if (!existingVendor.empty && existingVendor.docs[0].data().status !== 'rejected') {
    return jsonError('already_a_vendor', 400);
  }

  const body = await req.json();
  const ref = await db.collection('drivers').add({
    ownerId: auth.uid,
    vehicleType: body.vehicleType, // moto | voiture | coursier
    status: 'pending',
    isOnline: false,
    position: toGeoPoint(body.lat || 0, body.lng || 0),
    rating: 0,
    ratingCount: 0,
    documentsR2: body.documentsR2 || {},
    // Pays du candidat (déjà choisi à l'inscription) — un client d'un
    // autre pays ne verra jamais ce livreur tant qu'il n'a pas changé son
    // propre pays dans son profil. Voir drivers/nearby GET.
    country: auth.user.country || null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await logActivity('driver_applied', `Nouvelle candidature livreur/chauffeur en attente de vérification (${body.vehicleType})`, {
    driverId: ref.id,
    ownerId: auth.uid,
  });
  await notifyAdminByEmail({
    subject: 'Nouvelle candidature livreur/chauffeur à vérifier',
    htmlContent: `<p>Nouvelle candidature livreur/chauffeur (${body.vehicleType}).</p><p>Ouvrez le tableau de bord admin, section Chauffeurs, pour vérifier les documents et approuver ou rejeter.</p>`,
  });

  return Response.json({ id: ref.id, status: 'pending' });
}

// GET admin uniquement (liste + validation) — les clients ne listent pas les chauffeurs directement
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status');
  let query = db.collection('drivers');
  if (status) query = query.where('status', '==', status);
  query = query.orderBy('createdAt', 'desc').limit(200);
  try {
    const snap = await query.get();
    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[DRIVERS_GET_QUERY_ERROR]', { status, message: e.message, code: e.code });
    return jsonError('drivers_query_failed', 500);
  }
}
