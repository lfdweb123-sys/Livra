// Traductions françaises des statuts — utilisées dans les notifications
// (push + email) envoyées depuis le backend. BUG CORRIGE: les
// notifications envoyaient le statut technique brut non traduit (ex:
// "Votre commande est maintenant: accepted"), déjà signalé et jamais
// corrigé jusqu'ici.
export const ORDER_STATUS_LABELS_FR = {
  pending: 'en attente',
  accepted: 'acceptée',
  preparing: 'en préparation',
  picked_up: 'récupérée par le livreur',
  delivering: 'en cours de livraison',
  delivered: 'livrée',
  cancelled: 'annulée',
};

export const RIDE_STATUS_LABELS_FR = {
  pending: 'en attente',
  accepted: 'acceptée par le chauffeur',
  arriving: 'chauffeur en approche',
  in_progress: 'en cours',
  completed: 'terminée',
  cancelled: 'annulée',
};

export function orderStatusFr(status) {
  return ORDER_STATUS_LABELS_FR[status] || status;
}

export function rideStatusFr(status) {
  return RIDE_STATUS_LABELS_FR[status] || status;
}
