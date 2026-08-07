import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';

// Même tarif simple que les pubs produit — palier fixe par jour, pas d'enchères.
export const BOOST_PRICE_PER_DAY_XOF = 500;

// POST { profileType: 'driver'|'vendor', profileId, days } — crée le boost
// en attente de paiement. Une fois actif, le profil apparaît en premier:
// - pour un livreur/chauffeur/taxi-moto: dans /api/drivers/nearby (proposé
//   au client ou au vendeur qui cherche un livreur)
// - pour une boutique/restaurant: dans /api/vendors (liste publique)
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { profileType, profileId, days } = await req.json();
  if (!['driver', 'vendor'].includes(profileType)) return jsonError('invalid_profileType', 400);
  if (!profileId || !days || days < 1) return jsonError('invalid_params', 400);

  const collection = profileType === 'driver' ? 'drivers' : 'vendors';
  const profileSnap = await db.collection(collection).doc(profileId).get();
  if (!profileSnap.exists || profileSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  const pricePaid = BOOST_PRICE_PER_DAY_XOF * days;
  const ref = await db.collection('profile_boosts').add({
    profileType,
    profileId,
    ownerId: auth.uid,
    days,
    pricePaid,
    status: 'pending_payment',
    startAt: null,
    endAt: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  return Response.json({ id: ref.id, pricePaid });
}

// GET ?profileType=&profileId= — historique des boosts de ce profil
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const profileType = searchParams.get('profileType');
  const profileId = searchParams.get('profileId');
  if (!profileType || !profileId) return jsonError('profileType_and_profileId_required', 400);

  const collection = profileType === 'driver' ? 'drivers' : 'vendors';
  const profileSnap = await db.collection(collection).doc(profileId).get();
  if (!profileSnap.exists || profileSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  try {
    const snap = await db
      .collection('profile_boosts')
      .where('profileId', '==', profileId)
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();
    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[PROFILE_BOOSTS_GET_QUERY_ERROR]', { profileId, message: e.message, code: e.code });
    return jsonError('boosts_query_failed', 500);
  }
}
