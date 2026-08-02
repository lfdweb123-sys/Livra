// Emails transactionnels Brevo — confirmations commande, notifications
// de validation vendeur/chauffeur (remplace le "reviewedAt/rejectionReason"
// silencieux par un vrai email au destinataire).
//
// L'expéditeur doit être une adresse VÉRIFIÉE dans Brevo (Senders & IP >
// Senders), sinon Brevo rejette l'envoi en silence. Tant que le domaine
// livra.app n'est pas configuré (DKIM/SPF), on utilise une adresse Gmail
// vérifiée via BREVO_SENDER_EMAIL — configure-la dans Vercel une fois le
// domaine prêt, sans toucher au code.
export async function sendTransactionalEmail({ to, toName, subject, htmlContent }) {
  if (!process.env.BREVO_API_KEY) return { sent: false, reason: 'missing_api_key' };
  const senderEmail = process.env.BREVO_SENDER_EMAIL || 'gerardfreelancer123@gmail.com';
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { name: 'Livra', email: senderEmail },
      to: [{ email: to, name: toName || to }],
      subject,
      htmlContent,
    }),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    return { sent: false, reason: data.message || `http_${res.status}` };
  }
  return { sent: true };
}

export function vendorStatusEmail(businessName, status, rejectionReason) {
  if (status === 'active') {
    return {
      subject: 'Votre boutique Livra est activée 🎉',
      htmlContent: `<p>Bonjour,</p><p>Votre boutique <strong>${businessName}</strong> vient d'être validée. Vous pouvez dès maintenant publier votre catalogue et recevoir des commandes.</p>`,
    };
  }
  return {
    subject: 'Votre candidature vendeur Livra',
    htmlContent: `<p>Bonjour,</p><p>Votre candidature pour <strong>${businessName}</strong> n'a pas été retenue.${rejectionReason ? ` Motif : ${rejectionReason}.` : ''}</p>`,
  };
}

export function driverStatusEmail(status, rejectionReason) {
  if (status === 'active') {
    return {
      subject: 'Votre compte livreur Livra est activé 🎉',
      htmlContent: `<p>Bonjour,</p><p>Votre compte a été validé. Passez en ligne dans l'application pour recevoir vos premières courses.</p>`,
    };
  }
  return {
    subject: 'Votre candidature livreur Livra',
    htmlContent: `<p>Bonjour,</p><p>Votre candidature n'a pas été retenue.${rejectionReason ? ` Motif : ${rejectionReason}.` : ''}</p>`,
  };
}

export function orderDeliveredEmail(orderId, total) {
  return {
    subject: 'Votre commande Livra a été livrée',
    htmlContent: `<p>Bonjour,</p><p>Votre commande <strong>${orderId}</strong> (${total} XOF) a bien été livrée. Merci d'avoir utilisé Livra !</p>`,
  };
}
