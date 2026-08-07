// Tous les prix sont recalculés ici, jamais fait confiance au payload client.
import { distanceKm } from './geo';

const BASE_FEE = { moto: 300, voiture: 700, coursier: 400 };
const PER_KM = { moto: 150, voiture: 250, coursier: 150 };
const MIN_FEE = { moto: 300, voiture: 700, coursier: 400 };

// Frais de service Livra: 5% facturés à l'acheteur sur chaque transaction
// (commande vendeur/restaurant ET course livreur/chauffeur/taxi-moto).
// Les retraits (withdraw) restent gratuits — voir wallet/[userId]/withdraw,
// aucun frais n'y est appliqué.
export const SERVICE_FEE_PERCENT = 5;

export function computeServiceFee(amount) {
  return Math.round((amount * SERVICE_FEE_PERCENT) / 100);
}

// Suggestion de tarif par défaut (utilisée pour "aider à calculer" côté
// livreur, et comme calcul automatique tant qu'il n'a rien personnalisé).
export function suggestDeliveryFee(vehicleType, pickup, dropoff) {
  const km = distanceKm(pickup, dropoff);
  const fee = (BASE_FEE[vehicleType] || BASE_FEE.coursier) + km * (PER_KM[vehicleType] || PER_KM.coursier);
  return Math.max(Math.round(fee / 50) * 50, MIN_FEE[vehicleType] || MIN_FEE.coursier);
}

// Variante sans géopoints — pour afficher des exemples ("à 5 km : XXX XOF")
// dans l'écran "configurer mes tarifs" du profil livreur, sans dépendre
// d'une position réelle.
export function suggestDeliveryFeeForDistance(vehicleType, km) {
  const fee = (BASE_FEE[vehicleType] || BASE_FEE.coursier) + km * (PER_KM[vehicleType] || PER_KM.coursier);
  return Math.max(Math.round(fee / 50) * 50, MIN_FEE[vehicleType] || MIN_FEE.coursier);
}

// Chaque livreur/coursier/chauffeur/taxi-moto peut fixer ses propres frais
// de livraison selon l'adresse et la distance — soit en laissant le calcul
// automatique (barème plateforme ci-dessus), soit en configurant son propre
// tarif (baseFee + perKm + minFee) depuis son profil. Si aucun livreur
// précis n'est encore choisi pour la commande/course (cas du broadcast à
// tous les livreurs à proximité), le calcul automatique s'applique — il n'y
// a pas encore de livreur dont utiliser le tarif personnalisé.
export function computeDeliveryFee(vehicleType, pickup, dropoff, driverPricingConfig) {
  const km = distanceKm(pickup, dropoff);
  if (driverPricingConfig?.mode === 'custom') {
    const base = Number(driverPricingConfig.baseFee) || 0;
    const perKm = Number(driverPricingConfig.perKm) || 0;
    const min = Number(driverPricingConfig.minFee) || 0;
    const fee = base + km * perKm;
    return Math.max(Math.round(fee / 50) * 50, min);
  }
  const fee = (BASE_FEE[vehicleType] || BASE_FEE.coursier) + km * (PER_KM[vehicleType] || PER_KM.coursier);
  return Math.max(Math.round(fee / 50) * 50, MIN_FEE[vehicleType] || MIN_FEE.coursier);
}

// serviceFee calculé sur (subtotal + deliveryFee): l'acheteur paie 5% de
// plus sur l'ensemble de ce qu'il doit (articles + livraison), que ce
// frais soit dû à un vendeur/restaurant OU à un livreur.
export function computeOrderBreakdown({ items, vendorCommissionPercent, deliveryFee }) {
  const subtotal = items.reduce((sum, i) => sum + i.price * i.qty, 0);
  const commission = Math.round((subtotal * (vendorCommissionPercent || 0)) / 100);
  const serviceFee = computeServiceFee(subtotal + deliveryFee);
  const total = subtotal + deliveryFee + serviceFee;
  return { subtotal, deliveryFee, commission, serviceFee, serviceFeePercent: SERVICE_FEE_PERCENT, total };
}

export function computeRidePrice(vehicleType, pickup, dropoff, driverPricingConfig) {
  const km = distanceKm(pickup, dropoff);
  const basePrice = computeDeliveryFee(vehicleType, pickup, dropoff, driverPricingConfig);
  const serviceFee = computeServiceFee(basePrice);
  const price = basePrice + serviceFee; // total réellement facturé au client
  const etaMinutes = Math.max(3, Math.round((km / 25) * 60)); // 25km/h moyenne ville
  return {
    price,
    basePrice,
    serviceFee,
    serviceFeePercent: SERVICE_FEE_PERCENT,
    distanceKm: Number(km.toFixed(2)),
    etaMinutes,
  };
}
