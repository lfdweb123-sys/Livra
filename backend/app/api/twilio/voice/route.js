import { buildDialClientTwiml } from '../../../../lib/twilio';

// POST — webhook appelé PAR Twilio (pas par notre app), configuré comme
// "Voice Request URL" de la TwiML App. Reçoit le paramètre `To` envoyé par
// TwilioVoice.instance.call.place(from:, to:) côté mobile = l'uid Firebase
// du destinataire. Public par nécessité (Twilio n'envoie pas de token
// Firebase) — risque limité : au pire ça déclenche un appel client-à-client,
// pas d'accès aux données.
export async function POST(req) {
  const contentType = req.headers.get('content-type') || '';
  let to = null;

  if (contentType.includes('application/x-www-form-urlencoded')) {
    const formData = await req.formData();
    to = formData.get('To');
  } else {
    const body = await req.json().catch(() => ({}));
    to = body.To || body.to;
  }

  const twiml = buildDialClientTwiml(to);
  return new Response(twiml, { headers: { 'Content-Type': 'text/xml' } });
}
