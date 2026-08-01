import { db } from '../../../lib/firebaseAdmin';

// Public (pas de requireAuth) : appelé dès l'onboarding, avant connexion.
// Configuration des visuels gérés depuis le dashboard admin (carrousel
// accueil + slides onboarding), avec valeurs par défaut si jamais configuré.
export async function GET() {
  const snap = await db.collection('app_content').doc('config').get();
  const data = snap.exists ? snap.data() : {};
  return Response.json({
    bannersEnabled: data.bannersEnabled ?? true,
    banners: data.banners || [],
    onboardingEnabled: data.onboardingEnabled ?? true,
    onboardingSlides: data.onboardingSlides || [],
  });
}
