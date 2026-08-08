import { sendTransactionalEmail } from './brevo';
import { ADMIN_NOTIFICATION_EMAIL } from './config';

/// Alerte l'admin par email pour un événement nécessitant son attention
/// (nouvelle candidature vendeur/livreur, nouveau litige...). Ne fait rien
/// si ADMIN_NOTIFICATION_EMAIL n'est pas configuré sur Vercel — aucune
/// erreur, juste ignoré silencieusement.
export async function notifyAdminByEmail({ subject, htmlContent }) {
  if (!ADMIN_NOTIFICATION_EMAIL) return;
  try {
    await sendTransactionalEmail({ to: ADMIN_NOTIFICATION_EMAIL, toName: 'Admin Livra', subject, htmlContent });
  } catch (e) {
    console.error('[NOTIFY_ADMIN_EMAIL_ERROR]', e.message);
  }
}
