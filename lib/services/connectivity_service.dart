import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/core/log.dart';

part 'connectivity_service.g.dart';

/// Au moins un transport actif ?
///
/// Fonction pure, exposée : c'est la seule définition de « connecté » de
/// l'application, et elle doit être vérifiable sans plateforme.
///
/// ⚠️ Elle répond « un transport est disponible », pas « internet répond ».
/// Un WiFi de restaurant sans passerelle est « connecté » ici. C'est
/// suffisant pour ce qu'on en fait — expliquer un écran vide — et le vrai
/// verdict reste celui d'`ErrorInterceptor`, qui voit la requête échouer.
bool estConnecte(List<ConnectivityResult> resultats) => resultats.any(
  (r) =>
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn,
);

/// Point d'injection unique de `connectivity_plus` — le seul endroit du code
/// qui touche le plugin.
@Riverpod(keepAlive: true)
Connectivity connectivity(Ref ref) => Connectivity();

/// **L'état du réseau, sans trou.**
///
/// ## Le défaut que cette forme corrige
///
/// `ConnectivityService` publiait sur un `StreamController.broadcast()` et
/// l'exposait ainsi :
///
/// ```dart
/// Stream<bool> get connectionStream async* {
///   yield _isConnected;            // ← le générateur se suspend ICI
///   yield* _controller.stream;     // ← l'abonnement n'existe pas encore
/// }
/// ```
///
/// Entre ces deux lignes il y a un **trou asynchrone**, et un `broadcast` ne
/// rejoue rien : tout événement qui y tombe est perdu. Il s'en produit
/// précisément là — `_initConnectivity()` est lancé depuis le constructeur du
/// service et y écrit à cet instant.
///
/// Symptôme observé : au rétablissement de la connexion, l'événement `true`
/// disparaissait et **la bannière restait affichée** jusqu'au changement de
/// réseau suivant. Le correctif précédent (amorcer le flux) avait supprimé un
/// défaut en en créant un autre.
///
/// ## L'ordre qui compte
///
/// On **s'abonne d'abord**, on demande l'état courant **ensuite**. Dans
/// l'ordre inverse, un changement survenu pendant l'interrogation initiale
/// serait perdu — la même erreur, déplacée d'un cran.
///
/// `distinct()` : `connectivity_plus` émet à chaque changement de transport
/// (WiFi → mobile, ajout d'un VPN). Ces transitions ne changent pas la réponse
/// à « suis-je connecté ? », et les laisser passer ferait clignoter un message
/// sans raison.
///
/// ⚠️ La classe `ConnectivityService` a été **supprimée**. Elle ne portait que
/// cet état, et le détour par un service propriétaire d'un contrôleur était
/// exactement ce qui rendait le trou possible. Une abstraction de moins.
@riverpod
Stream<bool> connectivityStatus(Ref ref) {
  final connectivity = ref.watch(connectivityProvider);
  final sortie = StreamController<bool>();

  void publier(bool connecte) {
    if (!sortie.isClosed) sortie.add(connecte);
  }

  // 1. L'abonnement, AVANT tout le reste.
  final abonnement = connectivity.onConnectivityChanged.listen(
    (resultats) => publier(estConnecte(resultats)),
    onError: (Object e) => logDebug('Flux de connectivité en erreur : $e'),
  );

  // 2. L'état courant. Un échec de lecture vaut « connecté » : on ne barre pas
  //    l'écran d'un client dont le réseau va très bien parce qu'un plugin n'a
  //    pas répondu.
  unawaited(
    connectivity
        .checkConnectivity()
        .then((resultats) => publier(estConnecte(resultats)))
        .catchError((Object e) {
          logDebug('État de connectivité initial indisponible : $e');
          publier(true);
        }),
  );

  ref.onDispose(() {
    abonnement.cancel();
    sortie.close();
  });

  return sortie.stream.distinct();
}
