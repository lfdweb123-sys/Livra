// Pattern detecterPaysVerzapay (déjà utilisé sur FactuPro) : on route par indicatif
// téléphonique. FeexPay ne couvre que BJ/TG/CI/CG/SN/BF/ML avec un endpoint par
// réseau (l'utilisateur doit préciser son opérateur) ; Verzapay couvre plus de pays
// mais sans sélection d'opérateur (juste numéro), utile en fallback ou pour les
// pays hors zone FeexPay.
const FEEXPAY_COUNTRIES = ['229', '228', '225', '242', '221', '226', '223'];

export function detecterProvider(phoneNumber, preferredProvider) {
  const digits = phoneNumber.replace(/\D/g, '');
  if (preferredProvider === 'verzapay') return 'verzapay';
  if (preferredProvider === 'feexpay') {
    const coversFeexpay = FEEXPAY_COUNTRIES.some((c) => digits.startsWith(c));
    if (!coversFeexpay) throw new Error('feexpay_not_available_for_country');
    return 'feexpay';
  }
  // pas de préférence explicite : feexpay si couvert, sinon verzapay
  const coversFeexpay = FEEXPAY_COUNTRIES.some((c) => digits.startsWith(c));
  return coversFeexpay ? 'feexpay' : 'verzapay';
}
