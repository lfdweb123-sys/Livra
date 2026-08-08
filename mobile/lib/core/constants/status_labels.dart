/// Libellés français des statuts de commande/course — toujours utiliser
/// cette table plutôt que d'afficher le champ `status` brut (anglais).
const Map<String, String> kStatusLabelsFr = {
  'pending': 'En attente',
  'accepted': 'Acceptée',
  'preparing': 'En préparation',
  'picked_up': 'Prête / récupérée',
  'delivering': 'En livraison',
  'arriving': 'Chauffeur en approche',
  'in_progress': 'En cours',
  'delivered': 'Livrée',
  'completed': 'Terminée',
  'cancelled': 'Annulée',
  'rejected': 'Rejetée',
};

String statusLabelFr(String? status) => kStatusLabelsFr[status] ?? (status ?? '');

const Map<String, String> ORDER_TYPE_LABELS_FR = {
  'nourriture': 'Nourriture',
  'colis': 'Colis',
};

const Map<String, String> PAYMENT_STATUS_LABELS_FR = {
  'pending': 'en attente',
  'paid': 'payé',
  'failed': 'échoué',
};
