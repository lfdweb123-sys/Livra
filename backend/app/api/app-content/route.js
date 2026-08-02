import { db } from '../../../lib/firebaseAdmin';

// Public (pas de requireAuth) : appelé dès l'onboarding, avant connexion.
// Configuration des visuels gérés depuis le dashboard admin (carrousel
// accueil + slides onboarding), avec valeurs par défaut si jamais configuré.
//
// Sans paramètre de requête, Next.js met cette route en cache indéfiniment
// (même bug que /api/products/featured) — la case à cocher "Activé" semblait
// se recocher toute seule car load() re-servait une réponse mise en cache
// AVANT le PATCH, jamais la vraie valeur actualisée. force-dynamic corrige ça.
export const dynamic = 'force-dynamic';

export async function GET() {
  const snap = await db.collection('app_content').doc('config').get();
  const data = snap.exists ? snap.data() : {};
  return Response.json({
    bannersEnabled: data.bannersEnabled ?? true,
    banners: data.banners || [],
    onboardingEnabled: data.onboardingEnabled ?? true,
    onboardingSlides: data.onboardingSlides || [],
    supportEmail: data.supportEmail || 'support@livra.app',
    supportPhone: data.supportPhone || '',
    supportWhatsapp: data.supportWhatsapp || '',
  });
}
