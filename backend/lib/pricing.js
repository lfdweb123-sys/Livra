// Tous les prix sont recalculés ici, jamais fait confiance au payload client.
import { distanceKm } from './geo';

const BASE_FEE = { moto: 300, voiture: 700, coursier: 400 };
const PER_KM = { moto: 150, voiture: 250, coursier: 150 };
const MIN_FEE = { moto: 300, voiture: 700, coursier: 400 };

export function computeDeliveryFee(vehicleType, pickup, dropoff) {
  const km = distanceKm(pickup, dropoff);
  const fee = (BASE_FEE[vehicleType] || BASE_FEE.coursier) + km * (PER_KM[vehicleType] || PER_KM.coursier);
  return Math.max(Math.round(fee / 50) * 50, MIN_FEE[vehicleType] || MIN_FEE.coursier);
}

export function computeOrderBreakdown({ items, vendorCommissionPercent, deliveryFee }) {
  const subtotal = items.reduce((sum, i) => sum + i.price * i.qty, 0);
  const commission = Math.round((subtotal * (vendorCommissionPercent || 0)) / 100);
  const total = subtotal + deliveryFee;
  return { subtotal, deliveryFee, commission, total };
}

export function computeRidePrice(vehicleType, pickup, dropoff) {
  const km = distanceKm(pickup, dropoff);
  const price = computeDeliveryFee(vehicleType, pickup, dropoff);
  const etaMinutes = Math.max(3, Math.round((km / 25) * 60)); // 25km/h moyenne ville
  return { price, distanceKm: Number(km.toFixed(2)), etaMinutes };
}
