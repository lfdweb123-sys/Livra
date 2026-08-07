import { db, FieldValue } from './firebaseAdmin';

/// Enregistre un livreur/chauffeur HORS APPLICATION déclaré par un client
/// ou un vendeur, dans une collection dédiée — pour que l'équipe admin
/// puisse suivre ces livraisons qui échappent au suivi normal de la
/// plateforme (voir CGU : ce qui se passe hors plateforme n'engage pas
/// la responsabilité de Livra, mais on garde une trace pour le suivi).
export async function logOffPlatformDelivery({ phone, declaredBy, role, orderId, rideId }) {
  if (!phone) return;
  await db.collection('off_platform_deliveries').add({
    phone,
    declaredBy, // uid de qui a renseigné le numéro (client ou vendeur)
    role, // 'client' | 'vendor'
    orderId: orderId || null,
    rideId: rideId || null,
    createdAt: FieldValue.serverTimestamp(),
  });
}
