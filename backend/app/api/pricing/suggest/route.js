import { jsonError } from '../../../../lib/auth';
import { suggestDeliveryFeeForDistance } from '../../../../lib/pricing';

const DEFAULTS = {
  moto: { baseFee: 300, perKm: 150, minFee: 300 },
  voiture: { baseFee: 700, perKm: 250, minFee: 700 },
  coursier: { baseFee: 400, perKm: 150, minFee: 400 },
};

// GET ?vehicleType=moto|voiture|coursier — barème automatique par défaut
// pour ce type de véhicule + exemples de prix à différentes distances,
// utilisé côté profil livreur pour "aider à calculer" avant de choisir de
// personnaliser ou non son propre tarif.
export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const vehicleType = searchParams.get('vehicleType') || 'coursier';
  if (!DEFAULTS[vehicleType]) return jsonError('invalid_vehicleType', 400);

  const defaults = DEFAULTS[vehicleType];
  const examples = [1, 2, 3, 5, 10, 15].map((km) => ({
    km,
    fee: suggestDeliveryFeeForDistance(vehicleType, km),
  }));

  return Response.json({ vehicleType, defaults, examples });
}
