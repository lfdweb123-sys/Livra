import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';
import { distanceKm } from '../../../../lib/geo';

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
  const snap = await query.limit(200).get();

  const candidates = [];
  for (const doc of snap.docs) {
    const driver = doc.data();
    const pos = driver.position?.geopoint;
    if (!pos) continue;
    const dist = distanceKm({ latitude: lat, longitude: lng }, pos);
    if (dist > RADIUS_KM) continue;
    candidates.push({ id: doc.id, driver, distance: dist });
  }
  candidates.sort((a, b) => a.distance - b.distance);
  const top = candidates.slice(0, 20);

  // Enrichit avec le nom/photo depuis users/{ownerId} — le doc driver seul
  // ne contient ni nom ni photo de profil.
  const items = await Promise.all(
    top.map(async ({ id, driver, distance }) => {
      const userSnap = await db.collection('users').doc(driver.ownerId).get();
      const user = userSnap.exists ? userSnap.data() : {};
      return {
        id,
        name: user.name || 'Livreur Livra',
        photoUrl: driver.photoUrl || null,
        vehicleType: driver.vehicleType,
        rating: driver.rating || 0,
        ratingCount: driver.ratingCount || 0,
        bio: driver.bio || null,
        distanceKm: Number(distance.toFixed(2)),
      };
    })
  );

  return Response.json({ items });
}
