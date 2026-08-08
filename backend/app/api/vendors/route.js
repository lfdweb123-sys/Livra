import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { toGeoPoint } from '../../../lib/geo';
import { logActivity } from '../../../lib/activityLog';
import { notifyAdminByEmail } from '../../../lib/adminNotify';
import { boostTierFor, boostTierWeight } from '../../../lib/boostTiers';

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
    isOpen: true, // ouverte par défaut dès l'approbation admin — le vendeur
    // ne doit jamais avoir à penser à l'activer manuellement, seule la
    // fermeture (mise en pause) reste un choix manuel de sa part.
    // Pays du candidat (déjà choisi à l'inscription) — un client d'un
    // autre pays ne verra jamais cette boutique tant qu'il n'a pas changé
    // son propre pays dans son profil. Voir GET ci-dessous.
    country: auth.user.country || null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await logActivity('vendor_applied', `Nouvelle candidature vendeur en attente de vérification : ${body.businessName}`, {
    vendorId: ref.id,
    ownerId: auth.uid,
  });
  await notifyAdminByEmail({
    subject: 'Nouvelle candidature vendeur à vérifier',
    htmlContent: `<p>Nouvelle candidature vendeur : <strong>${body.businessName}</strong>.</p><p>Ouvrez le tableau de bord admin, section Vendeurs, pour vérifier les documents et approuver ou rejeter.</p>`,
  });

  return Response.json({ id: ref.id, status: 'pending' });
}

// GET — liste publique des vendeurs actifs (browse client), ou tous pour admin
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status') || 'active';
  const category = searchParams.get('category');
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);

  let query = db.collection('vendors').where('status', '==', status);
  if (category) query = query.where('category', '==', category);
  query = query.orderBy('createdAt', 'desc').limit(limit);
  try {
    const snap = await query.get();
    let items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    // Filtrage par pays — s'applique à TOUS les utilisateurs de l'app,
    // JAMAIS au tableau de bord admin (qui doit tout voir). Un document
    // sans champ "country" (créé avant ce filtrage) reste visible à tous,
    // pour ne pas rendre invisible le contenu déjà existant du jour au
    // lendemain — seul le nouveau contenu est vraiment scopé par pays.
    if (auth.role !== 'admin') {
      items = items.filter((v) => !v.country || v.country === auth.user.country);
    }

    // Boutiques/restaurants ayant boosté leur profil affichées en premier
    // selon le PALIER atteint par leur budget dépensé (Or > Argent >
    // Bronze), pas juste un booléen "boosté ou non" — l'ordre par date
    // reste inchangé au sein d'un même palier. Voir /api/boosts.
    const boostedPrices = await getActiveBoostedVendorPrices(items.map((v) => v.id));
    items.sort((a, b) => {
      const aWeight = boostedPrices.has(a.id) ? boostTierWeight(boostedPrices.get(a.id)) : 0;
      const bWeight = boostedPrices.has(b.id) ? boostTierWeight(boostedPrices.get(b.id)) : 0;
      return bWeight - aWeight;
    });
    return Response.json({
      items: items.map((v) => ({
        ...v,
        boosted: boostedPrices.has(v.id),
        boostTier: boostedPrices.has(v.id) ? boostTierFor(boostedPrices.get(v.id)) : null,
      })),
    });
  } catch (e) {
    console.error('[VENDORS_GET_QUERY_ERROR]', { status, category, message: e.message, code: e.code });
    return jsonError('vendors_query_failed', 500);
  }
}

async function getActiveBoostedVendorPrices(ids) {
  if (ids.length === 0) return new Map();
  const now = new Date();
  const boosted = new Map();
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
        if (b.endAt && b.endAt.toDate() > now) {
          const current = boosted.get(b.profileId) || 0;
          boosted.set(b.profileId, Math.max(current, b.pricePaid || 0));
        }
      });
    } catch (e) {
      console.error('[BOOSTS_LOOKUP_ERROR]', { profileType: 'vendor', message: e.message, code: e.code });
    }
  }
  return boosted;
}
