import { db } from '../../../../lib/firebaseAdmin';
import { jsonError } from '../../../../lib/auth';

// Public (pas de requireAuth — c'est justement AVANT la connexion) : permet
// de se connecter avec son numéro de téléphone au lieu de son email. On
// retrouve l'email associé, puis Firebase Auth s'occupe du mot de passe
// normalement côté client — cet endpoint ne reçoit ni ne vérifie aucun
// mot de passe, uniquement une correspondance téléphone -> email publique
// (comme un annuaire), pas une preuve d'identité.
export const dynamic = 'force-dynamic';

export async function POST(req) {
  const { phone } = await req.json();
  if (!phone) return jsonError('phone_required', 400);

  const snap = await db.collection('users').where('phone', '==', phone).limit(1).get();
  if (snap.empty) return jsonError('no_account_for_this_phone', 404);

  return Response.json({ email: snap.docs[0].data().email });
}
