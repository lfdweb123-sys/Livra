// Script de création d'un compte admin — à lancer une seule fois (ou pour
// chaque nouvel admin) depuis ta machine, jamais depuis l'app.
//
// Usage :
//   cd backend
//   node scripts/create-admin.js "admin@livra.app" "MotDePasseSolide123" "Nom Admin"
//
// Charge automatiquement backend/.env.local (mêmes variables que le backend).

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env.local') });

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const [, , email, password, name] = process.argv;

if (!email || !password) {
  console.error('Usage: node scripts/create-admin.js <email> <password> [nom]');
  process.exit(1);
}

initializeApp({
  credential: cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  }),
});

async function main() {
  const auth = getAuth();
  const db = getFirestore();

  let userRecord;
  try {
    userRecord = await auth.createUser({ email, password, displayName: name || 'Admin' });
    console.log('Compte Firebase Auth créé:', userRecord.uid);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      userRecord = await auth.getUserByEmail(email);
      console.log('Compte déjà existant, réutilisation:', userRecord.uid);
    } else {
      throw e;
    }
  }

  await db.collection('users').doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      role: 'admin',
      name: name || 'Admin',
      email,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(`\n✅ ${email} est maintenant admin. Connecte-toi sur le dashboard avec ce compte.`);
  process.exit(0);
}

main().catch((e) => {
  console.error('Erreur:', e);
  process.exit(1);
});
