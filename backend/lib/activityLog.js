// Journal d'activité — tout est automatisé côté plateforme (candidatures
// vendeur/livreur, matching, paiements...), l'admin n'approuve rien au
// quotidien. Son seul rôle est de VOIR les traces de ce qui se passe, et
// d'intervenir en cas d'abus (suspendre un compte) — jamais de valider
// manuellement chaque candidature ou transaction, ce qui serait intenable
// à surveiller à la main.
import { db, FieldValue } from './firebaseAdmin';

export async function logActivity(type, message, meta = {}) {
  try {
    await db.collection('activity_logs').add({
      type,
      message,
      meta,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // le logging ne doit jamais faire échouer l'action métier elle-même
    console.error('[ACTIVITY_LOG_ERROR]', e.message);
  }
}
