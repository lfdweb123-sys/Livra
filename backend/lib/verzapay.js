const BASE_URL = 'https://www.verzapay.com/api/v1';

function headers() {
  return {
    Authorization: `Bearer ${process.env.VERZAPAY_SECRET_KEY}`,
    'Content-Type': 'application/json',
  };
}

// Verzapay exige un customer_phone/recipient_phone d'au moins 6 caractères
// (idéalement E.164, ex: +22990000000). Sans ce champ l'API renvoie
// systématiquement une 400 "Donnée invalide (customer_phone)" et aucun
// lien de paiement n'est créé. On centralise la résolution ici: on essaie
// d'abord le numéro fourni explicitement par le client (saisi dans le
// formulaire de paiement), sinon on retombe sur le(s) numéro(s) de profil
// passés en fallback (ex: auth.user.phone). On normalise les espaces/tirets
// et on garde le préfixe +.
export function resolveCustomerPhone(...candidates) {
  for (const raw of candidates) {
    if (!raw) continue;
    const cleaned = raw.toString().trim().replace(/[\s\-().]/g, '');
    if (cleaned.length >= 6) return cleaned;
  }
  return null;
}

function assertPhone(phone, context) {
  const cleaned = resolveCustomerPhone(phone);
  if (!cleaned) {
    console.error(`[VERZAPAY_${context}_MISSING_PHONE]`, { phone });
    throw new Error('phone_required_for_payment');
  }
  return cleaned;
}

export async function verzapayCreatePayment({ amount, currency, description, customerName, customerPhone }) {
  const phone = assertPhone(customerPhone, 'PAYMENT');
  const res = await fetch(`${BASE_URL}/payments`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({
      amount,
      currency,
      description,
      customer_name: customerName,
      customer_phone: phone,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error('[VERZAPAY_PAYMENT_ERROR]', { httpStatus: res.status, response: data, amount, customerPhone: phone });
    throw new Error(data.error || data.message || `verzapay_http_${res.status}`);
  }
  return data; // { id, status, checkout_url }
}

export async function verzapayCreatePayout({ amount, currency, recipientPhone, recipientName }) {
  const phone = assertPhone(recipientPhone, 'PAYOUT');
  const res = await fetch(`${BASE_URL}/payouts`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({
      amount,
      currency,
      recipient_phone: phone,
      recipient_name: recipientName,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error('[VERZAPAY_PAYOUT_ERROR]', { httpStatus: res.status, response: data, amount, recipientPhone: phone });
    throw new Error(data.error || data.message || `verzapay_http_${res.status}`);
  }
  return data;
}
