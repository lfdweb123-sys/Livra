import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

// Prix simple, palier fixe par jour — pas d'enchères. Le vendeur choisit un
// produit + une durée, paye, c'est lancé. Voir README pour ajuster le tarif.
export const PRICE_PER_DAY_XOF = 500;

// POST { vendorId, productId, days } — crée la campagne en attente de paiement
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { vendorId, productId, days } = await req.json();
  if (!vendorId || !productId || !days || days < 1) return jsonError('invalid_params', 400);

  const vendorSnap = await db.collection('vendors').doc(vendorId).get();
  if (!vendorSnap.exists || vendorSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  const productSnap = await db.doc(`vendors/${vendorId}/products/${productId}`).get();
  if (!productSnap.exists) return jsonError('product_not_found', 404);

  const pricePaid = PRICE_PER_DAY_XOF * days;
  const ref = await db.collection('ad_campaigns').add({
    vendorId,
    productId,
    productName: productSnap.data().name,
    days,
    pricePaid,
    status: 'pending_payment',
    impressions: 0,
    clicks: 0,
    conversions: 0,
    startAt: null,
    endAt: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  return Response.json({ id: ref.id, pricePaid });
}

// GET ?vendorId=... — liste des campagnes du vendeur avec stats
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const vendorId = searchParams.get('vendorId');
  if (!vendorId) return jsonError('vendorId_required', 400);

  const vendorSnap = await db.collection('vendors').doc(vendorId).get();
  if (!vendorSnap.exists || vendorSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  try {
    const snap = await db.collection('ad_campaigns').where('vendorId', '==', vendorId).orderBy('createdAt', 'desc').limit(50).get();
    return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error('[AD_CAMPAIGNS_GET_QUERY_ERROR]', { vendorId, message: e.message, code: e.code });
    return jsonError('ad_campaigns_query_failed', 500);
  }
}
