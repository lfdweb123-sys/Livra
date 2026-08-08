import { adminAuth, db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';

// POST — suppression du compte demandée par l'utilisateur lui-même.
//
// IMPORTANT: on N'EFFACE PAS le document users/{uid} ni l'historique des
// commandes/courses/paiements — ce sont des preuves de transaction qui
// doivent rester consultables (voir la demande explicite plus tôt de
// conserver l'historique "à vie comme preuve"). On anonymise à la place
// les données personnelles (nom, téléphone, email) et on supprime le
// compte de connexion Firebase Auth lui-même — l'utilisateur ne peut plus
// se connecter, mais ses transactions passées restent traçables pour
// l'admin en cas de litige.
export async function POST(req) {
  const auth_ = await requireAuth(req);
  if (auth_.error) return jsonError(auth_.error, auth_.status);

  const uid = auth_.uid;

  // Un vendeur/livreur actif ne peut pas supprimer son compte directement
  // — il doit d'abord clôturer sa boutique/son profil (solde à retirer,
  // commandes en cours à terminer), sinon des transactions resteraient
  // bloquées sans propriétaire joignable.
  const [vendorSnap, driverSnap] = await Promise.all([
    db.collection('vendors').where('ownerId', '==', uid).where('status', '==', 'active').limit(1).get(),
    db.collection('drivers').where('ownerId', '==', uid).where('status', '==', 'active').limit(1).get(),
  ]);
  if (!vendorSnap.empty || !driverSnap.empty) {
    return jsonError('active_business_profile_exists', 400);
  }

  try {
    await db.collection('users').doc(uid).update({
      name: 'Compte supprimé',
      phone: null,
      email: null,
      city: null,
      fcmToken: null,
      isActive: false,
      accountDeletedAt: FieldValue.serverTimestamp(),
    });
    await adminAuth.deleteUser(uid);
    return Response.json({ ok: true });
  } catch (e) {
    console.error('[DELETE_ACCOUNT_ERROR]', uid, e.message);
    return jsonError('delete_account_failed', 500);
  }
}
