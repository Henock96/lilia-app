import 'package:flutter/foundation.dart';

/// **Le journal de diagnostic — et il se tait en production.**
///
/// ## Pourquoi `debugPrint` ne suffisait pas
///
/// Son nom trompe : `debugPrint` n'est **pas** retiré des builds de release.
/// C'est `debugPrintThrottled`, et il écrit sur la sortie standard de la
/// plateforme — logcat sur Android, Console.app sur iOS — quelle que soit la
/// configuration. Seuls les blocs gardés par `kDebugMode` ou `assert`
/// disparaissent.
///
/// L'application en comptait 81, dont :
///
/// ```dart
/// debugPrint('Message opened from background: ${message.data}');  // charge utile FCM entière
/// debugPrint('💳 Initiation du paiement — commande $orderId');
/// debugPrint('🔍 Checking payment status: $paymentId');
/// ```
///
/// Aucun jeton ni mot de passe — la discipline était bonne sur ce point —
/// mais des identifiants de commande et de paiement, et la charge utile
/// complète des notifications, lisibles sur l'appareil.
///
/// ## La règle
///
/// [logDebug] est le **seul** point de journalisation de l'application, et il
/// ne produit rien hors debug. Ce qui doit survivre en production a un autre
/// chemin, déjà en place : `Sentry.captureException` pour les incidents, et
/// `SentryNetworkObserver` pour le fil d'Ariane des requêtes — tous deux
/// configurés avec `sendDefaultPii = false`.
///
/// ⚠️ Ne jamais y passer un jeton, un mot de passe, un numéro de téléphone,
/// une adresse, ni une réponse d'API entière. Un identifiant technique
/// (commande, paiement) reste acceptable **parce que** rien n'en sort de
/// l'appareil.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
