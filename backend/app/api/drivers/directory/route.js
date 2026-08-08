import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { boostTierFor, boostTierWeight } from '../../../../lib/boostTiers';

// GET ?vehicleType=moto|voiture|coursier — annuaire public de TOUS les
// livreurs/coursiers/chauffeurs/taxi-motos actuellement actifs ET en
// ligne (pas seulement ceux à proximité — voir /api/drivers/nearby pour
// la recherche géo). Filtré par pays du demandeur, comme partout ailleurs.
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const vehicleType = searchParams.get('vehicleType');
  const limit = Math.min(parseInt(searchParams.get('limit') || '50', 10), 200);

  let query = db.collection('drivers').where('status', '==', 'active').where('isOnline', '==', true);
  if (vehicleType) query = query.where('vehicleType', '==', vehicleType);

  try {
    const snap = await query.limit(limit).get();
    let items = await Promise.all(
      snap.docs.map(async (d) => {
        const driver = d.data();
        const userSnap = await db.collection('users').doc(driver.ownerId).get();
        const user = userSnap.exists ? userSnap.data() : {};
        return {
          id: d.id,
          name: user.name || 'Livreur Livra',
          photoUrl: driver.photoUrl || null,
          vehicleType: driver.vehicleType,
          rating: driver.rating || 0,
          ratingCount: driver.ratingCount || 0,
          bio: driver.bio || null,
          completedCount: driver.completedCount || 0,
          country: driver.country || null,
        };
      })
    );

    if (auth.role !== 'admin') {
      items = items.filter((d) => !d.country || d.country === auth.user.country);
    }

    // Même logique de palier de boost que partout ailleurs.
    const boostedPrices = await getActiveBoostedPrices(items.map((d) => d.id));
    items.sort((a, b) => {
      const aWeight = boostedPrices.has(a.id) ? boostTierWeight(boostedPrices.get(a.id)) : 0;
      const bWeight = boostedPrices.has(b.id) ? boostTierWeight(boostedPrices.get(b.id)) : 0;
      return bWeight - aWeight;
    });

    return Response.json({
      items: items.map((d) => ({
        ...d,
        boosted: boostedPrices.has(d.id),
        boostTier: boostedPrices.has(d.id) ? boostTierFor(boostedPrices.get(d.id)) : null,
      })),
    });
  } catch (e) {
    console.error('[DRIVERS_DIRECTORY_QUERY_ERROR]', { vehicleType, message: e.message, code: e.code });
    return jsonError('drivers_directory_query_failed', 500);
  }
}

async function getActiveBoostedPrices(ids) {
  if (ids.length === 0) return new Map();
  const now = new Date();
  const boosted = new Map();
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    try {
      const snap = await db
        .collection('profile_boosts')
        .where('profileType', '==', 'driver')
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
      console.error('[BOOSTS_LOOKUP_ERROR]', { profileType: 'driver', message: e.message });
    }
  }
  return boosted;
}
