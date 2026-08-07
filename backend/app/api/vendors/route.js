import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { toGeoPoint } from '../../../lib/geo';
import { logActivity } from '../../../lib/activityLog';

// POST — un client candidate comme vendeur : statut "pending" jusqu'à
// vérification d'identité par l'admin (voir dashboard admin > Vendeurs).
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const body = await req.json();
  const existing = await db.collection('vendors').where('ownerId', '==', auth.uid).limit(1).get();
  if (!existing.empty) return jsonError('already_applied', 400);

  // Un compte ne peut être QUE vendeur OU livreur, jamais les deux —
  // vérifié aussi ici (pas seulement le bouton grisé côté app) au cas où
  // l'appel API serait fait directement.
  const existingDriver = await db.collection('drivers').where('ownerId', '==', auth.uid).limit(1).get();
  if (!existingDriver.empty && existingDriver.docs[0].data().status !== 'rejected') {
    return jsonError('already_a_driver', 400);
  }

  const ref = await db.collection('vendors').add({
    ownerId: auth.uid,
    businessName: body.businessName,
    category: body.category,
    status: 'pending',
    commission: 15,
    position: toGeoPoint(body.lat, body.lng),
    address: body.address || '',
    coverImageUrl: body.coverImageUrl || null,
    logoUrl: body.logoUrl || null,
    documents: body.documents || {},
    rating: 0,
    ratingCount: 0,
    isOpen: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await logActivity('vendor_applied', `Nouvelle candidature vendeur en attente de vérification : ${body.businessName}`, {
    vendorId: ref.id,
    ownerId: auth.uid,
  });

  return Response.json({ id: ref.id, status: 'pending' });
}

// GET — liste publique des vendeurs actifs (browse client), ou tous pour admin
export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status') || 'active';
  const category = searchParams.get('category');
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);

  let query = db.collection('vendors').where('status', '==', status);
  if (category) query = query.where('category', '==', category);
  query = query.orderBy('createdAt', 'desc').limit(limit);
  try {
    const snap = await query.get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    // Boutiques/restaurants ayant boosté leur profil affichées en premier
    // (voir /api/boosts) — l'ordre par date reste inchangé au sein de
    // chaque groupe (boostés / non boostés).
    const boostedIds = await getActiveBoostedVendorIds(items.map((v) => v.id));
    items.sort((a, b) => {
      const aBoosted = boostedIds.has(a.id) ? 0 : 1;
      const bBoosted = boostedIds.has(b.id) ? 0 : 1;
      return aBoosted - bBoosted;
    });
    return Response.json({ items: items.map((v) => ({ ...v, boosted: boostedIds.has(v.id) })) });
  } catch (e) {
    console.error('[VENDORS_GET_QUERY_ERROR]', { status, category, message: e.message, code: e.code });
    return jsonError('vendors_query_failed', 500);
  }
}

async function getActiveBoostedVendorIds(ids) {
  if (ids.length === 0) return new Set();
  const now = new Date();
  const boosted = new Set();
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    try {
      const snap = await db
        .collection('profile_boosts')
        .where('profileType', '==', 'vendor')
        .where('profileId', 'in', chunk)
        .where('status', '==', 'active')
        .get();
      snap.docs.forEach((d) => {
        const b = d.data();
        if (b.endAt && b.endAt.toDate() > now) boosted.add(b.profileId);
      });
    } catch (e) {
      console.error('[BOOSTS_LOOKUP_ERROR]', { profileType: 'vendor', message: e.message, code: e.code });
    }
  }
  return boosted;
}
