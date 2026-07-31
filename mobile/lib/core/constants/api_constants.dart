class ApiConstants {
  // URL de prod Vercel — surchageable via --dart-define=LIVRA_API_BASE_URL=...
  // (utile pour pointer vers un environnement de preview/staging si besoin).
  static const String baseUrl = String.fromEnvironment(
    'LIVRA_API_BASE_URL',
    defaultValue: 'https://livras.vercel.app',
  );

  static const String orders = '/api/orders';
  static const String rides = '/api/rides';
  static const String vendors = '/api/vendors';
  static const String drivers = '/api/drivers';
  static const String upload = '/api/upload';
  static const String walletBase = '/api/wallet';
  static const String directions = '/api/maps/directions';
  static const String distanceMatrix = '/api/maps/distance-matrix';
  static const String placesAutocomplete = '/api/maps/places-autocomplete';
  static const String feexpayInitiate = '/api/payments/feexpay/initiate';
  static const String verzapayInitiate = '/api/payments/verzapay/initiate';
}
