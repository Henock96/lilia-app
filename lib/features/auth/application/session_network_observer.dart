import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_observer.dart';
import 'session_guard.dart';

/// Relie **toutes** les erreurs d'API à la garde de session, en passant la main
/// à l'observateur existant.
///
/// Le point de branchement compte : `ApiClient._report` notifie son observateur
/// pour *chaque* erreur, quel que soit le dépôt à l'origine de l'appel. Un 401
/// est donc traité une fois, au même endroit, qu'il vienne des commandes, du
/// profil, des adresses ou du panier — plutôt que d'être rattrapé au cas par
/// cas dans chaque écran, ce qui n'était fait nulle part.
///
/// Décorateur et non remplacement : les fils d'Ariane Sentry continuent d'être
/// posés exactement comme avant.
class SessionAwareNetworkObserver implements NetworkObserver {
  const SessionAwareNetworkObserver(this._delegate, this._guard);

  final NetworkObserver _delegate;
  final SessionGuard _guard;

  @override
  void onRequest(RequestSnapshot r) => _delegate.onRequest(r);

  @override
  void onError(ApiException e, RequestSnapshot r) {
    _delegate.onError(e, r);
    // Volontairement non attendu : l'observateur est synchrone et ne doit pas
    // retarder la remontée de l'erreur à l'appelant. La garde absorbe
    // elle-même les appels concurrents, et un échec de déconnexion ne doit pas
    // masquer l'erreur d'origine.
    unawaited(_guard.handle(e).catchError((Object _) {}));
  }
}
