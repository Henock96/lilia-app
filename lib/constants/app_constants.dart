class AppConstants {
  /// Backend base URL. Overridable at build time via
  /// `--dart-define=API_URL=https://...` (e.g. staging, local tunnel).
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://lilia-backend.onrender.com',
  );

  /// WebSocket host (Socket.io upgrades from HTTP). Mirrors [baseUrl] by
  /// default but can be overridden independently with `--dart-define=WS_URL=...`.
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'https://lilia-backend.onrender.com',
  );

  static const String trackingNamespace = '/tracking';

  // Numéros de paiement Lilia (à configurer avec les vrais numéros)
  static const String mtnMomoPaymentNumber = '06 745 46 10';
  static const String airtelMoneyPaymentNumber = '05 555 00 01';
  static const double serviceFeeRate = 0.08;
}
