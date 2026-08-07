import { db, FieldValue } from './firebaseAdmin';

// Délai de retenue avant qu'un gain (commande livrée, course terminée) ne
// devienne disponible au retrait — le temps qu'une éventuelle réclamation
// du client puisse être traitée. S'applique à TOUS les prestataires
// (vendeur/restaurant/boutique, livreur/coursier/chauffeur/taxi-moto),
// jamais aux dépôts que le client fait lui-même sur son propre portefeuille
// (ceux-là restent immédiatement disponibles, voir webhooks paiement).
export const EARNINGS_HOLD_DAYS = 3;

/// Crédite un gain sur le portefeuille d'un prestataire — bloqué dans
/// `pendingBalance` jusqu'à ce que le cron mature-wallet-holds le libère
/// vers `balance` (disponible au retrait), EARNINGS_HOLD_DAYS jours plus
/// tard. Jamais retirable avant maturité, quel que soit le solde affiché.
export async function creditPendingEarnings({ userId, amount, reason, relatedOrderId, relatedRideId }) {
  if (!userId || !amount || amount <= 0) return;
  const availableAt = new Date(Date.now() + EARNINGS_HOLD_DAYS * 24 * 60 * 60 * 1000);
  const walletRef = db.collection('wallets').doc(userId);

  await walletRef.set(
    { pendingBalance: FieldValue.increment(amount), updatedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  await walletRef.collection('transactions').add({
    type: 'credit',
    amount,
    reason,
    relatedOrderId: relatedOrderId || null,
    relatedRideId: relatedRideId || null,
    availableAt,
    matured: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}
