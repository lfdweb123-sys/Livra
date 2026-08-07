import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { toGeoPoint } from '../../../../../lib/geo';

// POST { isOnline, lat, lng } — appelé à chaque toggle et à chaque update GPS pendant que le chauffeur est en ligne
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const ref = db.collection('drivers').doc(params.id);
  const snap = await ref.get();
  if (!snap.exists) return jsonError('not_found', 404);
  if (snap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);
  if (snap.data().status !== 'active') return jsonError('driver_not_active', 403);

  const { isOnline, lat, lng } = await req.json();
  const update = { isOnline, updatedAt: FieldValue.serverTimestamp() };
  if (lat !== undefined && lng !== undefined) update.position = toGeoPoint(lat, lng);
  await ref.update(update);

  if (isOnline) {
    // Auto-réparation: garantit que users/{ownerId}.activeDriverId est bien
    // synchronisé (utilisé par firestore.rules pour autoriser la lecture
    // des commandes/courses disponibles) — couvre le cas des livreurs déjà
    // actifs AVANT ce correctif, dont le profil admin n'a pas été retouché
    // depuis. Écriture légère (un seul champ, fusionnée), sans impact
    // notable même appelée à chaque mise à jour de position.
    //
    // BUG CORRIGE: cette écriture n'était PAS attendue (pas de await) —
    // la réponse "ok" partait immédiatement vers l'app, qui lançait alors
    // la requête géo des courses/commandes AVANT que activeDriverId ne
    // soit forcément déjà visible côté Firestore. Résultat: la toute
    // première tentative après un toggle échouait en permission-denied,
    // et comme un flux Firestore en erreur ne se relance jamais tout
    // seul, l'erreur restait affichée indéfiniment jusqu'au prochain
    // toggle manuel — exactement le symptôme observé.
    try {
      await db.collection('users').doc(auth.uid).set({ activeDriverId: params.id }, { merge: true });
    } catch (e) {
      console.error('[ACTIVE_DRIVER_ID_SYNC_ERROR]', auth.uid, e.message);
    }
  }

  return Response.json({ ok: true });
}
