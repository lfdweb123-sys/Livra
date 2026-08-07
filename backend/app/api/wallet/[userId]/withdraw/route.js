import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { verzapayCreatePayout, resolveCustomerPhone } from '../../../../../lib/verzapay';
import { feexpayCreatePayout, isValidPayoutNetwork, payoutRequiresOtp } from '../../../../../lib/feexpayPayout';

// POST { amount, phoneNumber, provider: 'verzapay'|'feexpay', network?, otp? }
// — décaissement du solde DISPONIBLE (hors fonds encore bloqués, voir la
// retenue de 3 jours sur les gains) vers Mobile Money. Retraits gratuits :
// aucun frais n'est jamais appliqué ici.
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.uid !== params.userId) return jsonError('forbidden', 403);

  const { amount, phoneNumber, provider, network, otp } = await req.json();
  if (!amount || amount <= 0) return jsonError('invalid_amount', 400);
  const walletRef = db.collection('wallets').doc(params.userId);

  if (provider === 'feexpay') {
    if (!isValidPayoutNetwork(network)) return jsonError('invalid_network', 400);
    if (payoutRequiresOtp(network) && !otp) return jsonError('otp_required', 400);
  }

  // On valide le téléphone AVANT de toucher au solde: inutile de débiter
  // puis rollback si on sait déjà que le paiement échouera.
  const recipientPhone = resolveCustomerPhone(phoneNumber, auth.user.phone);
  if (!recipientPhone) return jsonError('phone_required', 400);

  let walletTxId;
  try {
    walletTxId = await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef);
      // "balance" = uniquement les fonds DISPONIBLES (déjà passés le délai
      // de 3 jours) — les gains encore bloqués sont dans "pendingBalance"
      // et ne sont jamais retirables tant qu'ils n'ont pas mûri.
      const balance = walletSnap.exists ? walletSnap.data().balance || 0 : 0;
      if (balance < amount) throw new Error('insufficient_balance');
      tx.set(walletRef, { balance: FieldValue.increment(-amount), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      const txRef = walletRef.collection('transactions').doc();
      tx.set(txRef, {
        type: 'debit',
        amount,
        reason: 'withdrawal',
        createdAt: FieldValue.serverTimestamp(),
      });
      return txRef.id;
    });
  } catch (e) {
    if (e.message === 'insufficient_balance') return jsonError('insufficient_balance', 400);
    console.error('[WITHDRAW_ERROR]', e.message);
    return jsonError('withdraw_failed', 500);
  }

  const payoutRef = await db.collection('payouts').add({
    userId: params.userId,
    amount,
    provider,
    network: network || null,
    phoneNumber: recipientPhone,
    walletTransactionId: walletTxId,
    status: 'pending',
    providerReference: null,
    failReason: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  async function rollback(reason) {
    await walletRef.update({ balance: FieldValue.increment(amount), updatedAt: FieldValue.serverTimestamp() });
    await walletRef.collection('transactions').doc(walletTxId).update({ reason: 'withdrawal_failed_rollback' });
    await payoutRef.update({ status: 'failed', failReason: reason, updatedAt: FieldValue.serverTimestamp() });
  }

  try {
    if (provider === 'feexpay') {
      const result = await feexpayCreatePayout({
        network,
        phoneNumber: recipientPhone,
        amount,
        motif: 'Retrait Livra',
        otp,
        callbackInfo: payoutRef.id,
      });
      // Feexpay renvoie TOUJOURS "PENDING" au lancement — le statut final
      // (SUCCESSFUL/FAILED) doit être vérifié plus tard (voir
      // cron/reconcile-payouts), jamais supposé ici.
      await payoutRef.update({ providerReference: result.reference, status: 'pending_confirmation', updatedAt: FieldValue.serverTimestamp() });
      return Response.json({ ok: true, payoutId: payoutRef.id, status: 'pending_confirmation' });
    } else {
      const payout = await verzapayCreatePayout({
        amount,
        currency: 'XOF',
        recipientPhone,
        recipientName: auth.user.name,
      });
      await payoutRef.update({ providerReference: payout.id, status: 'pending_confirmation', updatedAt: FieldValue.serverTimestamp() });
      return Response.json({ ok: true, payoutId: payoutRef.id, status: 'pending_confirmation' });
    }
  } catch (e) {
    console.error('[WITHDRAW_PAYOUT_ERROR]', { userId: params.userId, amount, provider, network, message: e.message, stack: e.stack });
    await rollback(e.message);
    return jsonError(e.message, 400);
  }
}
