import { messaging, db, FieldValue } from './firebaseAdmin';

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

  if (!fcmToken) return { pushed: false, reason: 'no_token' };

  try {
    await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data: { type, relatedId: relatedId || '', ...data },
    });
    return { pushed: true };
  } catch (e) {
    return { pushed: false, reason: e.message };
  }
}
