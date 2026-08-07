import 'package:firebase_auth/firebase_auth.dart';
import 'remote_logger.dart';

/// Traduit N'IMPORTE QUELLE erreur (code backend, exception Firebase,
/// erreur réseau, etc.) en un message français lisible — à utiliser
/// PARTOUT à la place de "Erreur : $e", qui affichait directement les
/// codes d'erreur techniques du backend (ex: "insufficient_balance",
/// "phone_required"), tous en anglais, jamais traduits nulle part.
///
/// Règle stricte: cette fonction ne renvoie JAMAIS le texte brut de
/// l'exception d'origine si son code n'est pas reconnu — toujours un
/// message générique français plutôt qu'une fuite d'anglais.
String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    return RemoteLogger.readableAuthError(error);
  }

  // ApiClient enveloppe toujours l'erreur backend dans Exception(code) —
  // on retire le préfixe "Exception: " pour ne garder que le code.
  final raw = error.toString().replaceFirst('Exception: ', '').trim();

  const codes = {
    'ad_campaigns_query_failed': 'Impossible de charger les publicités. Réessayez.',
    'against_and_reason_required': 'Merci de préciser un motif de signalement.',
    'already_a_driver': 'Vous avez déjà une candidature livreur en cours.',
    'already_a_vendor': 'Vous avez déjà une candidature vendeur en cours.',
    'already_applied': 'Vous avez déjà postulé.',
    'already_assigned': 'Un livreur est déjà assigné à cette commande.',
    'already_paid': 'Ce paiement a déjà été effectué.',
    'already_processed': 'Cette opération a déjà été traitée.',
    'already_reviewed': 'Vous avez déjà laissé un avis pour cette commande.',
    'boosts_query_failed': 'Impossible de charger les boosts. Réessayez.',
    'disputes_query_failed': 'Impossible de charger les signalements. Réessayez.',
    'driver_not_active': "Ce livreur n'est plus actif.",
    'driver_unavailable': "Ce livreur n'est plus disponible.",
    'drivers_nearby_query_failed': 'Impossible de charger les livreurs à proximité. Réessayez.',
    'drivers_query_failed': 'Impossible de charger les livreurs. Réessayez.',
    'file_too_large': 'Le fichier est trop volumineux.',
    'forbidden': "Vous n'avez pas accès à cette action.",
    'insufficient_balance': 'Solde insuffisant sur votre portefeuille.',
    'invalid_amount': 'Montant invalide.',
    'invalid_network': 'Réseau Mobile Money invalide.',
    'invalid_params': 'Informations invalides. Vérifiez le formulaire.',
    'invalid_provider': 'Moyen de paiement invalide.',
    'invalid_rating': 'Note invalide.',
    'lat_lng_required': 'Position GPS requise.',
    'locations_required': 'Merci de renseigner les adresses.',
    'no_account_for_this_phone': 'Aucun compte associé à ce numéro.',
    'no_service_fee_due': 'Aucun frais de service dû sur cette commande.',
    'no_target_to_review': "Rien à évaluer pour l'instant.",
    'not_found': 'Introuvable.',
    'not_yet_completed': "Cette commande/course n'est pas encore terminée.",
    'off_platform_deliveries_query_failed': 'Impossible de charger les livraisons hors application. Réessayez.',
    'orders_query_failed': 'Impossible de charger les commandes. Réessayez.',
    'origin_destination_required': 'Merci de renseigner le départ et la destination.',
    'otp_required': 'Le code OTP est requis pour ce réseau.',
    'payment_already_processed': 'Ce paiement a déjà été traité.',
    'phone_required': 'Numéro de téléphone requis pour ce paiement.',
    'product_not_found': 'Produit introuvable.',
    'reviews_query_failed': 'Impossible de charger les avis. Réessayez.',
    'rides_query_failed': 'Impossible de charger les courses. Réessayez.',
    'service_fee_required': "Les frais de service doivent d'abord être réglés.",
    'target_not_found': 'Introuvable.',
    'vendor_assigns_driver': 'Le vendeur choisit le livreur pour cette commande.',
    'vendor_unavailable': "Cette boutique/restaurant n'est plus disponible.",
    'vendors_query_failed': 'Impossible de charger les boutiques. Réessayez.',
    'withdraw_failed': 'Le retrait a échoué. Réessayez.',
    // Réseau / connexion (voir ApiClient._extractError)
    'délai dépassé, vérifiez votre connexion': 'Délai dépassé — vérifiez votre connexion internet.',
    'pas de connexion réseau': 'Pas de connexion réseau. Vérifiez votre connexion internet.',
    'erreur réseau': 'Erreur réseau. Réessayez.',
  };

  if (codes.containsKey(raw)) return codes[raw]!;

  // Certaines routes renvoient un message dynamique (ex: erreur brute
  // d'un fournisseur de paiement) plutôt qu'un code fixe — jamais fait
  // confiance à son contenu (peut être en anglais), toujours un message
  // générique français à la place.
  return "Une erreur est survenue. Réessayez dans un instant.";
}
