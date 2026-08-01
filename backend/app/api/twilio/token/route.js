import { requireAuth, jsonError } from '../../../../lib/auth';
import { generateVoiceAccessToken } from '../../../../lib/twilio';

// GET — jeton Twilio Voice pour l'utilisateur connecté. Son identité Twilio
// = son uid Firebase, ce qui permet à /api/twilio/voice de router un appel
// vers "le client identifié par cet uid" sans registre séparé.
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  try {
    const token = generateVoiceAccessToken(auth.uid);
    return Response.json({ token, identity: auth.uid });
  } catch (e) {
    return jsonError(`twilio_token_error:${e.message}`, 500);
  }
}
