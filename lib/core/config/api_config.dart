// lib/core/config/api_config.dart

class ApiConfig {
  // --- CHANGEZ CETTE LIGNE ---
  // Mettez `true` pour tester sur l'émulateur Android.
  // Mettez `false` pour tester sur un appareil physique.
  static const bool isEmulator = false;

  // --- NE PAS CHANGER LE RESTE ---

  // URL pour l'émulateur Android (qui pointe vers le localhost de la machine hôte)
  static const String _emulatorBaseUrl = "http://10.0.2.2:3000";

  // URL pour un appareil physique (utilisez l'IP de votre ordinateur sur le réseau local)
  // Pour trouver votre IP : `ipconfig` sur Windows, `ifconfig` sur macOS/Linux
  static const String _physicalDeviceBaseUrl = "http://192.168.52.134:3000"; // <--- REMPLACEZ L'IP ICI

  // L'URL de base qui sera utilisée dans toute l'application
  static String get baseUrl {
    if (isEmulator) {
      return _emulatorBaseUrl;
    } else {
      return _physicalDeviceBaseUrl;
    }
  }
}
