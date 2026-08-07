/// Traduction française de CHAQUE motif de transaction portefeuille produit
/// par le backend (voir tous les appels `reason:` dans backend/app et
/// backend/lib) — jamais le code brut affiché à l'écran (ex:
/// "delivery_earnings").
const Map<String, String> kWalletReasonLabelsFr = {
  'order_payment': 'Paiement de commande',
  'ride_payment': 'Paiement de course',
  'wallet_deposit': 'Dépôt sur le portefeuille',
  'withdrawal': 'Retrait',
  'withdrawal_failed_refund': 'Retrait échoué — remboursé',
  'withdrawal_failed_rollback': 'Retrait annulé — remboursé',
  'order_earnings': 'Gain — commande livrée',
  'ride_earnings': 'Gain — course terminée',
  'delivery_earnings': 'Gain — livraison effectuée',
  'ad_campaign': 'Publicité produit',
  'profile_boost': 'Boost de profil',
  'service_fee_cash_order': 'Frais de service (commande espèces)',
  'service_fee_cash_ride': 'Frais de service (course espèces)',
};

String walletReasonLabelFr(String? reason) => kWalletReasonLabelsFr[reason] ?? 'Transaction';
