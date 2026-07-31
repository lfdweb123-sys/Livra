// Init unique de firebase-admin, réutilisé par toutes les routes API.
// Ne jamais importer firebase (client SDK) ici.
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue as FV, Timestamp as TS } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';

function initAdmin() {
  if (getApps().length) return getApps()[0];
  return initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      // Vercel stocke les \n littéraux dans les env vars, il faut les reconvertir
      privateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
    }),
  });
}

const app = initAdmin();
export const db = getFirestore(app);
export const adminAuth = getAuth(app);
export const messaging = getMessaging(app);
export const FieldValue = FV;
export const Timestamp = TS;
