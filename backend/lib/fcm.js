import { messaging, db, FieldValue } from './firebaseAdmin';

// Codes d'erreur FCM indiquant un token définitivement invalide (app
// désinstallée, token expiré/remplacé côté OS...) — pas la peine de
// réessayer, il faut nettoyer le token pour ne plus jamais retenter dessus.
const DEAD_TOKEN_ERRORS = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

// Envoie un push + écrit toujours le doc notifications (source de vérité affichée dans l'app)
export async function sendNotification({ userId, title, body, type, relatedId, data = {} }) {
  const userSnap = await db.collection('users').doc(userId).get();
  const fcmToken = userSnap.exists ? userSnap.data().fcmToken : null;

  await db.collection('notifications').add({
    userId,
    title,
    body,
    type,
    relatedId: relatedId || null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  if (!fcmToken) {
    console.warn('[FCM_NO_TOKEN]', { userId, title });
    return { pushed: false, reason: 'no_token' };
  }

  try {
    await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data: { type, relatedId: relatedId || '', ...data },
    });
    return { pushed: true };
  } catch (e) {
    // IMPORTANT: 'NotRegistered' (code messaging/registration-token-not-registered)
    // veut dire que ce token FCM ne sera JAMAIS valide à nouveau — sans ce
    // nettoyage, on retentait silencieusement sur le même token mort à
    // chaque notification pour cet utilisateur, indéfiniment, sans qu'il
    // ne reçoive jamais rien. Le token sera régénéré tout seul à sa
    // prochaine connexion (voir le code Flutter qui l'enregistre au login).
    if (DEAD_TOKEN_ERRORS.includes(e.code)) {
      console.warn('[FCM_DEAD_TOKEN_CLEARED]', { userId, code: e.code });
      await db.collection('users').doc(userId).update({ fcmToken: FieldValue.delete() }).catch(() => {});
    } else {
      console.error('[FCM_SEND_ERROR]', { userId, code: e.code, message: e.message });
    }
    return { pushed: false, reason: e.code || e.message };
  }
}
