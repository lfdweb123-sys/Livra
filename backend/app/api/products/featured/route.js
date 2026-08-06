import { db } from '../../../../lib/firebaseAdmin';

// Sans paramètre de requête, Next.js essaierait de pré-générer cette route
// STATIQUEMENT au moment du build (donc d'exécuter la requête Firestore
// avant même que l'app tourne) — on force le mode dynamique pour l'exécuter
// à chaque appel, comme toutes les autres routes.
export const dynamic = 'force-dynamic';

// Découverte accueil : mélange aléatoire de produits, recalculé côté client
// toutes les minutes. Les produits sous campagne publicitaire active
// passent en premier (l'ordre entre eux dépend du montant payé), le reste
// du quota est complété par une sélection aléatoire parmi tous les
// produits disponibles.
const RESULT_SIZE = 12;

export async function GET() {
  const now = new Date();

  // 1. Produits actuellement boostés par une pub payée
  // NOTE: cette requête combine where(status) + where(endAt, '>') +
  // orderBy(endAt) + orderBy(pricePaid) — elle EXIGE un index composite
  // Firestore. Sans lui, .get() lève une exception. On isole ce bloc du
  // reste de la réponse: si l'index manque, on continue quand même avec
  // la sélection aléatoire plutôt que de casser tout le fil d'accueil.
  const boostedProductIds = new Set();
  const boosted = [];
  try {
    const adsSnap = await db
      .collection('ad_campaigns')
      .where('status', '==', 'active')
      .where('endAt', '>', now)
      .orderBy('endAt')
      .orderBy('pricePaid', 'desc')
      .limit(RESULT_SIZE)
      .get();

    for (const doc of adsSnap.docs) {
      const campaign = doc.data();
      if (boostedProductIds.has(campaign.productId)) continue;
      const productSnap = await db.doc(`vendors/${campaign.vendorId}/products/${campaign.productId}`).get();
      if (!productSnap.exists || !productSnap.data().isAvailable) continue;
      boostedProductIds.add(campaign.productId);
      boosted.push({ id: productSnap.id, ...productSnap.data(), sponsored: true, campaignId: doc.id });
      // impression comptabilisée à l'affichage réel côté client (POST /api/ads/track), pas ici
    }
  } catch (e) {
    console.error('[FEATURED_PRODUCTS_ADS_QUERY_ERROR]', { message: e.message, code: e.code });
  }

  // 2. Complète avec une sélection aléatoire parmi les produits disponibles
  // NOTE: collectionGroup() avec un filtre EXIGE lui aussi un index composite
  // dédié aux collection groups — distinct de l'index d'une collection
  // normale 'products'. À créer séparément dans Firestore si absent.
  const remaining = RESULT_SIZE - boosted.length;
  let random = [];
  if (remaining > 0) {
    try {
      const pool = await db.collectionGroup('products').where('isAvailable', '==', true).limit(300).get();
      const candidates = pool.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((p) => !boostedProductIds.has(p.id));
      for (let i = candidates.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [candidates[i], candidates[j]] = [candidates[j], candidates[i]];
      }
      random = candidates.slice(0, remaining);
    } catch (e) {
      console.error('[FEATURED_PRODUCTS_POOL_QUERY_ERROR]', { message: e.message, code: e.code });
    }
  }

  return Response.json({ items: [...boosted, ...random] });
}
