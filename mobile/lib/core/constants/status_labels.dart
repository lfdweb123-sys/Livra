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
