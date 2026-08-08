import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { distanceKm } from '../../../../lib/geo';
import { boostTierFor, boostTierWeight } from '../../../../lib/boostTiers';

const RADIUS_KM = 8;

// GET ?lat=&lng=&vehicleType= — livreurs/chauffeurs actifs ET en ligne à
// proximité, avec nom/photo/note. Utilisé par le client (choisir un
// livreur pour un colis/une course) ET par le vendeur (choisir qui doit
// venir récupérer une commande prête) — l'un comme l'autre restent
// TOUJOURS libres de ne rien choisir et de passer par un livreur hors
// application (voir CGU: ce qui se passe hors plateforme n'engage pas
// Livra).
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const lat = parseFloat(searchParams.get('lat'));
  const lng = parseFloat(searchParams.get('lng'));
  const vehicleType = searchParams.get('vehicleType');
  if (Number.isNaN(lat) || Number.isNaN(lng)) return jsonError('lat_lng_required', 400);

  let query = db.collection('drivers').where('status', '==', 'active').where('isOnline', '==', true);
  if (vehicleType) query = query.where('vehicleType', '==', vehicleType);
  let snap;
  try {
    snap = await query.limit(200).get();
  } catch (e) {
    console.error('[DRIVERS_NEARBY_QUERY_ERROR]', { vehicleType, message: e.message, code: e.code });
    return jsonError('drivers_nearby_query_failed', 500);
  }

  const candidates = [];
  for (const doc of snap.docs) {
    const driver = doc.data();
    // Filtrage par pays — un client d'un pays ne voit jamais un livreur
    // d'un autre pays, sauf s'il change son propre pays dans son profil.
    // Un livreur sans "country" (créé avant ce filtrage) reste visible à
    // tous pour ne pas rendre invisible le contenu déjà existant.
    if (driver.country && driver.country !== auth.user.country) continue;
    const pos = driver.position?.geopoint;
    if (!pos) continue;
    const dist = distanceKm({ latitude: lat, longitude: lng }, pos);
    if (dist > RADIUS_KM) continue;
    candidates.push({ id: doc.id, driver, distance: dist });
  }

  // Profils boostés (payants) mis en priorité selon le PALIER atteint par
  // leur budget dépensé (Or > Argent > Bronze), pas juste un booléen
  // "boosté ou non" — un profil ayant payé davantage passe devant un
  // profil ayant boosté au tarif minimum. Toujours dans le rayon de
  // recherche, jamais un livreur hors zone. Voir /api/boosts.
  const boostedPrices = await getActiveBoostedPrices('driver', candidates.map((c) => c.id));
  candidates.sort((a, b) => {
    const aWeight = boostedPrices.has(a.id) ? boostTierWeight(boostedPrices.get(a.id)) : 0;
    const bWeight = boostedPrices.has(b.id) ? boostTierWeight(boostedPrices.get(b.id)) : 0;
    if (aWeight !== bWeight) return bWeight - aWeight;
    return a.distance - b.distance;
  });
  const top = candidates.slice(0, 20);

  // Enrichit avec le nom/photo depuis users/{ownerId} — le doc driver seul
  // ne contient ni nom ni photo de profil.
  const items = await Promise.all(
    top.map(async ({ id, driver, distance }) => {
      const userSnap = await db.collection('users').doc(driver.ownerId).get();
      const user = userSnap.exists ? userSnap.data() : {};
      const boosted = boostedPrices.has(id);
      return {
        id,
        name: user.name || 'Livreur Livra',
        photoUrl: driver.photoUrl || null,
        vehicleType: driver.vehicleType,
        rating: driver.rating || 0,
        ratingCount: driver.ratingCount || 0,
        bio: driver.bio || null,
        distanceKm: Number(distance.toFixed(2)),
        boosted,
        boostTier: boosted ? boostTierFor(boostedPrices.get(id)) : null,
      };
    })
  );

  return Response.json({ items });
}

// Retourne le budget total dépensé (pricePaid) par profileId ayant un
// boost actif (status='active' ET endAt dans le futur) parmi la liste
// donnée. Requête par lots de 30 (limite Firestore pour l'opérateur 'in').
async function getActiveBoostedPrices(profileType, ids) {
  if (ids.length === 0) return new Map();
  const now = new Date();
  const boosted = new Map();
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    try {
      const snap = await db
        .collection('profile_boosts')
        .where('profileType', '==', profileType)
        .where('profileId', 'in', chunk)
        .where('status', '==', 'active')
        .get();
      snap.docs.forEach((d) => {
        const b = d.data();
        if (b.endAt && b.endAt.toDate() > now) {
          // Si plusieurs boosts actifs pour le même profil, garde le plus
          // gros budget dépensé pour déterminer le palier.
          const current = boosted.get(b.profileId) || 0;
          boosted.set(b.profileId, Math.max(current, b.pricePaid || 0));
        }
      });
    } catch (e) {
      console.error('[BOOSTS_LOOKUP_ERROR]', { profileType, message: e.message, code: e.code });
    }
  }
  return boosted;
}
