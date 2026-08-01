import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { logActivity } from '../../../../../lib/activityLog';

// PATCH { isActive: false } — désactive un compte (non-respect des règles).
// Pas de suppression dure ici : ça casserait l'historique commandes/paiements
// liés à cet uid. La désactivation empêche juste toute connexion utile.
export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const { isActive } = await req.json();
  await db.collection('users').doc(params.uid).update({ isActive, updatedAt: FieldValue.serverTimestamp() });
  await logActivity(
    isActive ? 'user_reactivated' : 'user_deactivated',
    `Compte utilisateur ${isActive ? 'réactivé' : 'désactivé'} par l'admin`,
    { uid: params.uid, adminUid: auth.uid }
  );
  return Response.json({ ok: true });
}
