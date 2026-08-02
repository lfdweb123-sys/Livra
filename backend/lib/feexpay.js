// FeexPay V2 — un endpoint par réseau. Le network est choisi côté client
// (l'utilisateur sait s'il paie en MTN/Moov/Wave/Orange) et validé ici.
const BASE_URL = 'https://api-v2.feexpay.me/api/transactions/public/requesttopay';

// networks supportés (étendu BF/ML comme sur FactuPro)
const NETWORKS = [
  'mtn', 'moov', 'celtiis_bj', 'coris', // Bénin
  'togocom_tg', 'moov_tg', // Togo
  'mtn_ci', 'moov_ci', 'wave_ci', 'orange_ci', // Côte d'Ivoire
  'mtn_cg', // Congo Brazzaville
  'orange_sn', 'wave_sn', 'free_sn', // Sénégal
  'moov_bf', 'orange_bf', 'wave_bf', // Burkina Faso
  'orange_ml', 'mobicash_ml', // Mali
];

// Réseaux nécessitant un OTP généré par l'utilisateur avant l'appel (ex: Orange BF, Coris)
export const OTP_REQUIRED_NETWORKS = ['coris', 'orange_bf'];

export function isValidNetwork(network) {
  return NETWORKS.includes(network);
}

export async function feexpayRequestToPay({ network, phoneNumber, amount, firstName, lastName, description, callbackInfo, otp }) {
  if (!isValidNetwork(network)) throw new Error('invalid_network');

  const payload = {
    shop: process.env.FEEXPAY_SHOP_ID,
    amount,
    phoneNumber,
    first_name: firstName || 'Livra',
    last_name: lastName || 'Client',
    description: description || 'Paiement Livra',
    callback_info: callbackInfo,
  };
  if (OTP_REQUIRED_NETWORKS.includes(network)) payload.otp = otp || '';

  const res = await fetch(`${BASE_URL}/${network}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.FEEXPAY_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json();
  if (!res.ok) {
    // Log complet cote serveur (Vercel > Deployments > Functions > Logs) —
    // le message renvoye au client est deja fidele, mais sans ce log on ne
    // voit jamais la vraie reponse FeexPay pour diagnostiquer.
    console.error('[FEEXPAY_ERROR]', {
      network,
      httpStatus: res.status,
      // numéro partiellement masqué (pas undefined — juste pas en clair)
      requestPhoneNumberMasked: phoneNumber ? `${phoneNumber.slice(0, 6)}***${phoneNumber.slice(-2)}` : null,
      amount: payload.amount,
      feexpayMessage: data.message,
      feexpayErrorsDetail: JSON.stringify(data.errors),
      feexpayFullResponse: data,
    });
    throw new Error(data.message || `feexpay_http_${res.status}`);
  }
  console.log('[FEEXPAY_SUCCESS]', { network, reference: data.reference || data.order_id });
  return data; // { reference, status: PENDING, ... } ou { payment_url } selon réseau
}
