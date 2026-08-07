// Vérification obligatoire des payouts Feexpay — leur API renvoie toujours
// PENDING au lancement d'un retrait, il faut interroger le statut final
// séparément (pas de webhook fiable pour les payouts, contrairement au
// payin). Appelé toutes les 5 min par le même service cron externe que
// reconcile-payments (voir ce fichier pour la configuration).
import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { feexpayPayoutStatus } from '../../../../lib/feexpayPayout';
import { sendNotification } from '../../../../lib/fcm';

export async function GET(req) {
  const secret = req.headers.get('x-cron-secret');
  if (secret !== process.env.INTERNAL_API_SECRET) {
    return Response.json({ error: 'forbidden' }, { status: 403 });
  }

  const snap = await db
    .collection('payouts')
    .where('provider', '==', 'feexpay')
    .where('status', '==', 'pending_confirmation')
    .limit(50)
    .get();

  let checked = 0;
  let confirmed = 0;
  let failed = 0;

  for (const doc of snap.docs) {
    const payout = doc.data();
    if (!payout.providerReference) continue;
    checked++;
    try {
      const result = await feexpayPayoutStatus(payout.providerReference);
      if (result.status === 'SUCCESSFUL') {
        await doc.ref.update({ status: 'successful', updatedAt: FieldValue.serverTimestamp() });
        await sendNotification({
          userId: payout.userId,
          title: 'Retrait effectué',
          body: `${payout.amount} XOF ont été envoyés vers votre Mobile Money.`,
          type: 'withdrawal_successful',
          relatedId: doc.id,
        });
        confirmed++;
      } else if (result.status === 'FAILED') {
        // recrédite le wallet — le montant avait été débité immédiatement
        // à la demande de retrait, avant confirmation du fournisseur
        const walletRef = db.collection('wallets').doc(payout.userId);
        await walletRef.update({ balance: FieldValue.increment(payout.amount), updatedAt: FieldValue.serverTimestamp() });
        await walletRef.collection('transactions').add({
          type: 'credit',
          amount: payout.amount,
          reason: 'withdrawal_failed_refund',
          relatedPayoutId: doc.id,
          createdAt: FieldValue.serverTimestamp(),
        });
        await doc.ref.update({ status: 'failed', failReason: result.reason || null, updatedAt: FieldValue.serverTimestamp() });
        await sendNotification({
          userId: payout.userId,
          title: 'Retrait échoué',
          body: `Votre retrait de ${payout.amount} XOF a échoué — le montant a été recrédité sur votre portefeuille.`,
          type: 'withdrawal_failed',
          relatedId: doc.id,
        });
        failed++;
      }
      // sinon toujours PENDING côté Feexpay — on retentera au prochain passage
    } catch (e) {
      console.error('[RECONCILE_PAYOUTS_ERROR]', { payoutId: doc.id, message: e.message });
    }
  }

  return Response.json({ checked, confirmed, failed });
}
