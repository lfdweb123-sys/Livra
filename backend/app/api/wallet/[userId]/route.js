import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.uid !== params.userId && auth.role !== 'admin') return jsonError('forbidden', 403);

  const walletSnap = await db.collection('wallets').doc(params.userId).get();
  const balance = walletSnap.exists ? walletSnap.data().balance || 0 : 0;
  // Gains encore bloqués (retenue de 3 jours, voir lib/wallet.js) — jamais
  // retirables tant qu'ils n'ont pas mûri, mais affichés pour transparence.
  const pendingBalance = walletSnap.exists ? walletSnap.data().pendingBalance || 0 : 0;

  const { searchParams } = new URL(req.url);
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);
  const txSnap = await db
    .collection(`wallets/${params.userId}/transactions`)
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return Response.json({
    balance,
    pendingBalance,
    transactions: txSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
  });
}
