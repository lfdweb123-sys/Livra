// Twilio Programmable Voice — génération de jeton d'accès + routage des
// appels (client Flutter <-> client Flutter, via identité = uid Firebase).
// Configuration requise dans Twilio Console (voir README) :
//   1. Créer une TwiML App, pointer sa "Voice Request URL" vers
//      https://<ton-domaine>/api/twilio/voice (méthode POST)
//   2. Récupérer : Account SID, API Key SID + Secret, TwiML App SID
//   3. Générer une Push Credential Android (FCM Server Key) pour recevoir
//      les appels app fermée — voir la doc Twilio "Updating Twilio Push
//      for FCM HTTP v1 API"
import twilio from 'twilio';

const AccessToken = twilio.jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;

export function generateVoiceAccessToken(identity) {
  const token = new AccessToken(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_API_KEY_SID,
    process.env.TWILIO_API_KEY_SECRET,
    { identity, ttl: 3600 }
  );

  const voiceGrant = new VoiceGrant({
    outgoingApplicationSid: process.env.TWILIO_TWIML_APP_SID,
    pushCredentialSid: process.env.TWILIO_ANDROID_PUSH_CREDENTIAL_SID || undefined,
  });
  token.addGrant(voiceGrant);

  return token.toJwt();
}

export function buildDialClientTwiml(toIdentity) {
  const VoiceResponse = twilio.twiml.VoiceResponse;
  const response = new VoiceResponse();
  if (!toIdentity) {
    response.say({ language: 'fr-FR' }, "Numéro invalide, impossible d'établir l'appel.");
    return response.toString();
  }
  const dial = response.dial({ timeout: 30 });
  dial.client(toIdentity);
  return response.toString();
}
