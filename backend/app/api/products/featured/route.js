import { db } from '../../../../lib/firebaseAdmin';

// Découverte accueil : mélange aléatoire de produits, recalculé côté client
// toutes les minutes. Les produits sous campagne publicitaire active
// passent en premier (l'ordre entre eux dépend du montant payé), le reste
// du quota est complété par une sélection aléatoire parmi tous les
// produits disponibles.
const RESULT_SIZE = 12;

export async function GET() {
  const now = new Date();

  // 1. Produits actuellement boostés par une pub payée
  const adsSnap = await db
    .collection('ad_campaigns')
    .where('status', '==', 'active')
    .where('endAt', '>', now)
    .orderBy('endAt')
    .orderBy('pricePaid', 'desc')
    .limit(RESULT_SIZE)
    .get();

  const boostedProductIds = new Set();
  const boosted = [];
  for (const doc of adsSnap.docs) {
    const campaign = doc.data();
    if (boostedProductIds.has(campaign.productId)) continue;
    const productSnap = await db.doc(`vendors/${campaign.vendorId}/products/${campaign.productId}`).get();
    if (!productSnap.exists || !productSnap.data().isAvailable) continue;
    boostedProductIds.add(campaign.productId);
    boosted.push({ id: productSnap.id, ...productSnap.data(), sponsored: true, campaignId: doc.id });
    // impression comptabilisée à l'affichage réel côté client (POST /api/ads/track), pas ici
  }

  // 2. Complète avec une sélection aléatoire parmi les produits disponibles
  const remaining = RESULT_SIZE - boosted.length;
  let random = [];
  if (remaining > 0) {
    const pool = await db.collectionGroup('products').where('isAvailable', '==', true).limit(300).get();
    const candidates = pool.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((p) => !boostedProductIds.has(p.id));
    for (let i = candidates.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [candidates[i], candidates[j]] = [candidates[j], candidates[i]];
    }
    random = candidates.slice(0, remaining);
  }

  return Response.json({ items: [...boosted, ...random] });
}
