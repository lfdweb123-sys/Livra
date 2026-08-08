// Superviseur IA quotidien — rassemble les événements des dernières 24h
// (litiges, paiements échoués, commandes bloquées, comportements
// suspects) et demande à Claude d'en faire un résumé clair avec des
// actions concrètes pour l'admin, plutôt que de le laisser éplucher les
// journaux d'activité manuellement. Appelé une fois par jour par le
// service cron externe (voir reconcile-payments pour la configuration).
import { db } from '../../../../lib/firebaseAdmin';
import { notifyAdminByEmail } from '../../../../lib/adminNotify';
import { sendNotification } from '../../../../lib/fcm';
import { ADMIN_NOTIFICATION_EMAIL } from '../../../../lib/config';

export async function GET(req) {
  const secret = req.headers.get('x-cron-secret');
  if (secret !== process.env.INTERNAL_API_SECRET) {
    return Response.json({ error: 'forbidden' }, { status: 403 });
  }
  if (!process.env.ANTHROPIC_API_KEY) {
    return Response.json({ skipped: 'ANTHROPIC_API_KEY non configurée' });
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [disputesSnap, paymentsSnap, ordersSnap, ridesSnap] = await Promise.all([
    db.collection('disputes').where('createdAt', '>=', since).get(),
    db.collection('payments').where('status', '==', 'failed').where('createdAt', '>=', since).get(),
    db.collection('orders').where('createdAt', '>=', since).get(),
    db.collection('rides').where('createdAt', '>=', since).get(),
  ]);

  // Commandes/courses créées il y a plus de 2h et toujours "pending" —
  // signe qu'elles n'ont jamais été prises en charge (vendeur absent,
  // aucun livreur disponible...).
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
  const stuckOrders = ordersSnap.docs.filter((d) => d.data().status === 'pending' && d.data().createdAt?.toDate() < twoHoursAgo).length;
  const stuckRides = ridesSnap.docs.filter((d) => d.data().status === 'pending' && d.data().createdAt?.toDate() < twoHoursAgo).length;

  // Comportement suspect simple : commande marquée "delivered" moins de
  // 60 secondes après avoir été acceptée par le livreur (quasi
  // impossible physiquement) — signale un risque de fraude à vérifier.
  const suspiciouslyFast = [];
  for (const doc of ordersSnap.docs) {
    const history = doc.data().statusHistory || [];
    const accepted = history.find((h) => h.status === 'picked_up');
    const delivered = history.find((h) => h.status === 'delivered');
    if (accepted && delivered) {
      const diffSec = (new Date(delivered.at) - new Date(accepted.at)) / 1000;
      if (diffSec >= 0 && diffSec < 60) suspiciouslyFast.push(doc.id);
    }
  }

  const stats = {
    nouveauxLitiges: disputesSnap.size,
    paiementsEchoues: paymentsSnap.size,
    commandesBloquees: stuckOrders,
    coursesBloquees: stuckRides,
    commandesTotales: ordersSnap.size,
    coursesTotales: ridesSnap.size,
    livraisonsSuspectesRapides: suspiciouslyFast.length,
  };

  // Rien de notable : pas la peine de déranger l'admin avec un rapport vide.
  const hasAnything = stats.nouveauxLitiges + stats.paiementsEchoues + stats.commandesBloquees + stats.coursesBloquees + stats.livraisonsSuspectesRapides > 0;
  if (!hasAnything) {
    return Response.json({ skipped: 'rien de notable', stats });
  }

  const prompt = `Tu es l'assistant de supervision quotidien de Livra, une plateforme de livraison/courses/boutiques en ligne en Afrique de l'Ouest. Voici les statistiques des dernières 24 heures :

${JSON.stringify(stats, null, 2)}

Rédige un court rapport en français (5-8 phrases maximum), clair et actionnable, pour l'administrateur de la plateforme :
- Résume ce qui mérite son attention aujourd'hui
- Si "livraisonsSuspectesRapides" > 0, souligne que ce sont des commandes marquées livrées moins d'une minute après acceptation — à vérifier manuellement, cela peut indiquer une fraude
- Si "commandesBloquees" ou "coursesBloquees" > 0, suggère de vérifier pourquoi (manque de vendeurs/livreurs actifs dans une zone ?)
- Termine par 1 à 3 actions concrètes recommandées, sous forme de liste
- Reste factuel, sans exagérer la gravité si les chiffres sont bas
- N'utilise aucun format Markdown (pas de #, pas de **) — texte brut avec des retours à la ligne, ce sera inséré directement dans un email`;

  let summary;
  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 600,
        messages: [{ role: 'user', content: prompt }],
      }),
    });
    const data = await res.json();
    summary = data.content?.map((c) => c.text || '').join('\n') || 'Résumé indisponible.';
  } catch (e) {
    console.error('[AI_SUPERVISOR_CLAUDE_ERROR]', e.message);
    summary = `Résumé automatique indisponible (erreur technique). Statistiques brutes : ${JSON.stringify(stats)}`;
  }

  await notifyAdminByEmail({
    subject: `Rapport quotidien Livra — ${new Date().toLocaleDateString('fr-FR')}`,
    htmlContent: `<div style="font-family:sans-serif;white-space:pre-line;line-height:1.6">${summary}</div>`,
  });

  // Notifie aussi tous les comptes admin par push, pour ceux qui ont
  // l'app installée (pas seulement l'email).
  if (ADMIN_NOTIFICATION_EMAIL) {
    const adminsSnap = await db.collection('users').where('role', '==', 'admin').get();
    await Promise.all(
      adminsSnap.docs.map((d) =>
        sendNotification({
          userId: d.id,
          title: 'Rapport quotidien disponible',
          body: 'Votre résumé IA des dernières 24h a été envoyé par email.',
          type: 'ai_daily_report',
        }).catch(() => {})
      )
    );
  }

  return Response.json({ ok: true, stats });
}
