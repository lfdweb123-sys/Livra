// FeexPay Payout V2 — un endpoint par réseau/pays (contrairement au payin qui
// a un seul endpoint + paramètre network). Documentation fournie: chaque
// réseau a sa propre URL, certains acceptent un champ `network` en plus
// (Bénin global, Togo), d'autres non (CI, Sénégal, Congo, Mali).
const BASE = 'https://api-v2.feexpay.me/api/payouts/public';

// Réseau -> { path, networkField?: valeur à envoyer dans le body, otpRequired? }
const PAYOUT_NETWORKS = {
  // Bénin
  mtn: { path: 'transfer/global', networkField: 'MTN' },
  moov: { path: 'transfer/global', networkField: 'MOOV' },
  celtiis_bj: { path: 'celtiis_bj', networkField: 'CELTIIS BJ' },
  // Côte d'Ivoire
  mtn_ci: { path: 'mtn_ci' },
  orange_ci: { path: 'orange_ci' },
  moov_ci: { path: 'moov_ci' },
  wave_ci: { path: 'wave_ci' },
  // Togo
  togocom_tg: { path: 'togo', networkField: 'TOGOCOM TG' },
  moov_tg: { path: 'togo', networkField: 'MOOV TG' },
  // Sénégal
  orange_sn: { path: 'orange_sn' },
  free_sn: { path: 'free_sn' },
  wave_sn: { path: 'wave_sn' },
  // Congo Brazzaville
  mtn_cg: { path: 'mtn_cg' },
  // Burkina Faso
  moov_bf: { path: 'moov_bf' },
  orange_bf: { path: 'orange_bf', otpRequired: true }, // OTP via #144*4*6*montant#
  wave_bf: { path: 'wave_bf', otpRequired: true }, // OTP via appli Wave ou USSD
  // Mali
  orange_ml: { path: 'orange_ml' },
  mobicash_ml: { path: 'mobicash_ml' },
};

export function isValidPayoutNetwork(network) {
  return Object.prototype.hasOwnProperty.call(PAYOUT_NETWORKS, network);
}

export function payoutRequiresOtp(network) {
  return !!PAYOUT_NETWORKS[network]?.otpRequired;
}

// motif: 30 caractères max, sans caractères spéciaux (contrainte FeexPay)
function sanitizeMotif(motif) {
  return (motif || 'Livra').replace(/[^a-zA-Z0-9 ]/g, '').slice(0, 30) || 'Livra';
}

export async function feexpayCreatePayout({ network, phoneNumber, amount, motif, otp, callbackInfo, email }) {
  const cfg = PAYOUT_NETWORKS[network];
  if (!cfg) throw new Error('invalid_payout_network');

  const cleanPhoneNumber = (phoneNumber || '').replace(/[^0-9]/g, '');

  const payload = {
    shop: process.env.FEEXPAY_SHOP_ID,
    amount,
    phoneNumber: cleanPhoneNumber,
    motif: sanitizeMotif(motif),
    callback_info: callbackInfo || null,
  };
  if (cfg.networkField) payload.network = cfg.networkField;
  if (email) payload.email = email;
  if (cfg.otpRequired) {
    if (!otp) throw new Error('otp_required_for_this_network');
    payload.otp = otp;
  }

  const res = await fetch(`${BASE}/${cfg.path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.FEEXPAY_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json();
  if (!res.ok) {
    console.error('[FEEXPAY_PAYOUT_ERROR]', {
      network,
      httpStatus: res.status,
      requestPhoneNumberMasked: cleanPhoneNumber ? `${cleanPhoneNumber.slice(0, 6)}***${cleanPhoneNumber.slice(-2)}` : null,
      amount,
      feexpayMessage: data.message,
      feexpayFullResponse: data,
    });
    throw new Error(data.message || `feexpay_payout_http_${res.status}`);
  }
  console.log('[FEEXPAY_PAYOUT_ACCEPTED]', { network, reference: data.reference, status: data.status });
  return data; // { reference, status: 'PENDING', amount, phone_number, ... }
}

// La doc FeexPay insiste: la vérification du statut est OBLIGATOIRE après un
// payout (toujours PENDING au lancement) — pas de webhook fiable pour les
// payouts, donc on interroge cet endpoint (voir cron/reconcile-payouts).
export async function feexpayPayoutStatus(reference) {
  const res = await fetch(`https://api-v2.feexpay.me/api/payouts/status/public/${reference}`, {
    headers: { Authorization: `Bearer ${process.env.FEEXPAY_API_KEY}` },
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `feexpay_payout_status_http_${res.status}`);
  return data; // { status: 'PENDING'|'SUCCESSFUL'|'FAILED', reason, ... }
}

export async function feexpayGetBalance() {
  const shopId = process.env.FEEXPAY_SHOP_ID;
  const res = await fetch(`https://api-v2.feexpay.me/api/balance/public/getByShop/${shopId}`, {
    headers: { Authorization: `Bearer ${process.env.FEEXPAY_API_KEY}` },
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `feexpay_balance_http_${res.status}`);
  return data;
}
