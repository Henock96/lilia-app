import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // La clé vient de `ios/Flutter/MapsKeys.local.xcconfig` (gitignoré) via
    // Info.plist. Elle n'a rien à faire dans le code : une clé committée reste
    // dans l'historique git à jamais.
    //
    // ⚠️ Ne pas appeler `provideAPIKey` ne produit pas une carte grise : le SDK
    // Google Maps iOS lève une exception **fatale** à la première `GMSMapView`.
    // L'app crashait donc à l'ouverture du suivi, longtemps après le
    // démarrage, sans rapport apparent avec une clé manquante. On échoue
    // maintenant tout de suite, avec la marche à suivre.
    let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String ?? ""
    if apiKey.isEmpty || apiKey == "YOUR_GOOGLE_MAPS_API_KEY" || apiKey == "YOUR_IOS_MAPS_API_KEY" {
      #if DEBUG
      // En debug on laisse tourner : un développeur qui ne touche pas aux
      // cartes n'a pas à réclamer une clé pour lancer l'app.
      NSLog("[Lilia] Clé Google Maps absente — les écrans de carte vont crasher. "
            + "Renseignez GOOGLE_MAPS_API_KEY dans ios/Flutter/MapsKeys.local.xcconfig.")
      #else
      fatalError(
        "Clé Google Maps absente. Créez ios/Flutter/MapsKeys.local.xcconfig "
        + "avec GOOGLE_MAPS_API_KEY=<clé>. Sans elle, tout écran de carte "
        + "fait crasher l'application."
      )
      #endif
    } else {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
