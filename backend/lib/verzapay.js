const BASE_URL = 'https://www.verzapay.com/api/v1';

function headers() {
  return {
    Authorization: `Bearer ${process.env.VERZAPAY_SECRET_KEY}`,
    'Content-Type': 'application/json',
  };
}

export async function verzapayCreatePayment({ amount, currency, description, customerName, customerPhone }) {
  const res = await fetch(`${BASE_URL}/payments`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({
      amount,
      currency,
      description,
      customer_name: customerName,
      customer_phone: customerPhone,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || 'verzapay_error');
  return data; // { id, status, checkout_url }
}

export async function verzapayCreatePayout({ amount, currency, recipientPhone, recipientName }) {
  const res = await fetch(`${BASE_URL}/payouts`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({
      amount,
      currency,
      recipient_phone: recipientPhone,
      recipient_name: recipientName,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || 'verzapay_error');
  return data;
}
