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

  // Les numéros d'encaissement Mobile Money et le taux de commission ne sont
  // volontairement plus ici : ils viennent du serveur.
  //
  //  • numéro et montant à payer   → `POST /payments` (`instructions.phone`,
  //    `instructions.amount`), donc modifiables par variable Render sans
  //    release mobile ;
  //  • taux de commission / fidélité → `GET /platform-settings`
  //    (`platformSettingsProvider`).
  //
  // Les coder en dur laissait notamment un numéro Airtel placeholder
  // ('05 555 00 01') affiché aux clients en production.
}
