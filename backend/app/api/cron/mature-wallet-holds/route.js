// Fait passer les gains bloqués depuis 3 jours (commandes livrées, courses
// terminées) de pendingBalance vers balance (disponible au retrait) — le
// délai de retenue permet de traiter une éventuelle réclamation avant que
// l'argent ne soit retirable. Appelé toutes les heures par le service cron
// externe (voir reconcile-payments pour la configuration générale).
import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { sendNotification } from '../../../../lib/fcm';

export async function GET(req) {
  const secret = req.headers.get('x-cron-secret');
  if (secret !== process.env.INTERNAL_API_SECRET) {
    return Response.json({ error: 'forbidden' }, { status: 403 });
  }

  const now = new Date();
  const snap = await db
    .collectionGroup('transactions')
    .where('matured', '==', false)
    .where('availableAt', '<=', now)
    .limit(200)
    .get();

  let matured = 0;
  // Regroupe par utilisateur pour n'envoyer QU'UNE notification par
  // passage du cron, même si plusieurs gains mûrissent en même temps —
  // sinon un livreur avec 5 livraisons du même jour recevrait 5
  // notifications identiques d'un coup.
  const maturedByUser = {};

  for (const doc of snap.docs) {
    const tx = doc.data();
    const walletRef = doc.ref.parent.parent; // wallets/{uid}
    if (!walletRef) continue;
    try {
      await db.runTransaction(async (t) => {
        t.update(walletRef, {
          pendingBalance: FieldValue.increment(-tx.amount),
          balance: FieldValue.increment(tx.amount),
          updatedAt: FieldValue.serverTimestamp(),
        });
        t.update(doc.ref, { matured: true, maturedAt: FieldValue.serverTimestamp() });
      });
      matured++;
      maturedByUser[walletRef.id] = (maturedByUser[walletRef.id] || 0) + tx.amount;
    } catch (e) {
      console.error('[MATURE_WALLET_HOLDS_ERROR]', { walletId: walletRef.id, txId: doc.id, message: e.message });
    }
  }

  // Notifie chaque utilisateur concerné, une seule fois, avec le total.
  await Promise.all(
    Object.entries(maturedByUser).map(([userId, amount]) =>
      sendNotification({
        userId,
        title: 'Argent disponible',
        body: `${amount} XOF sont maintenant disponibles au retrait sur votre portefeuille.`,
        type: 'earnings_matured',
      }).catch((e) => console.error('[MATURE_WALLET_HOLDS_NOTIF_ERROR]', userId, e.message))
    )
  );

  return Response.json({ matured, usersNotified: Object.keys(maturedByUser).length });
}
