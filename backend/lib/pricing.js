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

export function computeDeliveryFee(vehicleType, pickup, dropoff) {
  const km = distanceKm(pickup, dropoff);
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

export function computeRidePrice(vehicleType, pickup, dropoff) {
  const km = distanceKm(pickup, dropoff);
  const basePrice = computeDeliveryFee(vehicleType, pickup, dropoff);
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
