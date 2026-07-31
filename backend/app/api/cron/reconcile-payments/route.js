// Reconciliation paiements — pattern identique à paymentgateway.lfdweb.com :
// appelé toutes les 5 min par cron-job.org (GET avec header secret).
// FeexPay/Verzapay n'exposent pas d'endpoint "check status" documenté ici,
// donc la réconciliation applique une règle simple : tout paiement encore
// "pending" après 20 min est marqué "failed" (le webhook, s'il arrive après,
// ne re-touchera pas un paiement déjà "successful", donc pas de risque de
// double-crédit ; si le provider répond après coup, il faut alors gérer
// manuellement depuis le dashboard admin).
import { db, FieldValue } from '../../../../lib/firebaseAdmin';

const TIMEOUT_MINUTES = 20;

export async function GET(req) {
  const secret = req.headers.get('x-cron-secret');
  if (secret !== process.env.INTERNAL_API_SECRET) {
    return Response.json({ error: 'forbidden' }, { status: 403 });
  }

  const cutoff = new Date(Date.now() - TIMEOUT_MINUTES * 60 * 1000);
  const snap = await db
    .collection('payments')
    .where('status', '==', 'pending')
    .where('createdAt', '<=', cutoff)
    .limit(100)
    .get();

  const batch = db.batch();
  snap.docs.forEach((doc) => {
    batch.update(doc.ref, { status: 'failed', updatedAt: FieldValue.serverTimestamp(), failReason: 'timeout_reconciliation' });
  });
  if (!snap.empty) await batch.commit();

  return Response.json({ reconciled: snap.size });
}
