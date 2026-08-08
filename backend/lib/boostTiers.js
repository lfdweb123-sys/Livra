// Paliers de visibilité selon le budget total dépensé sur une campagne
// (boost de profil ou pub produit) — plus le budget est élevé, plus le
// profil/produit est mis en avant. Basé sur BOOST_PRICE_PER_DAY_XOF = 500
// (voir api/boosts/route.js) : 1 jour = 500 XOF.
export const BOOST_TIERS = {
  gold: { minSpend: 5000, label: 'Or' }, // 10+ jours
  silver: { minSpend: 2000, label: 'Argent' }, // 4-9 jours
  bronze: { minSpend: 0, label: 'Bronze' }, // 1-3 jours
};

export function boostTierFor(pricePaid) {
  if (pricePaid >= BOOST_TIERS.gold.minSpend) return 'gold';
  if (pricePaid >= BOOST_TIERS.silver.minSpend) return 'silver';
  return 'bronze';
}

// Poids numérique pour trier (plus haut = affiché en premier).
const TIER_WEIGHT = { gold: 3, silver: 2, bronze: 1 };
export function boostTierWeight(pricePaid) {
  return TIER_WEIGHT[boostTierFor(pricePaid)];
}
