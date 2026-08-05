import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';
import { verzapayCreatePayout, resolveCustomerPhone } from '../../../../../lib/verzapay';

// POST { amount, phoneNumber } — décaissement du solde wallet Livra vers Mobile Money
export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.uid !== params.userId) return jsonError('forbidden', 403);

  const { amount, phoneNumber } = await req.json();
  const walletRef = db.collection('wallets').doc(params.userId);

  // On valide le téléphone AVANT de toucher au solde: inutile de débiter
  // puis rollback si on sait déjà que Verzapay refusera le payout.
  const recipientPhone = resolveCustomerPhone(phoneNumber, auth.user.phone);
  if (!recipientPhone) return jsonError('phone_required', 400);

  let result;
  try {
    result = await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef);
      const balance = walletSnap.exists ? walletSnap.data().balance : 0;
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

  try {
    const payout = await verzapayCreatePayout({
      amount,
      currency: 'XOF',
      recipientPhone,
      recipientName: auth.user.name,
    });
    return Response.json({ ok: true, transactionId: result, payoutId: payout.id });
  } catch (e) {
    console.error('[WITHDRAW_PAYOUT_ERROR]', { userId: params.userId, amount, phoneNumber, message: e.message, stack: e.stack });
    // rollback du débit si le payout échoue au niveau de l'appel API
    await walletRef.update({ balance: FieldValue.increment(amount) });
    await walletRef.collection('transactions').doc(result).update({ reason: 'withdrawal_failed_rollback' });
    return jsonError(e.message, 400);
  }
}
