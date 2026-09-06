import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

import 'analytics_events.dart';
import 'lilia_analytics.dart';

/// Observateur de navigation — la source unique de `page_view` sur mobile.
///
/// Il remplace `FirebaseAnalyticsObserver` et fait deux choses distinctes, qui
/// ne se recouvrent pas :
///
///  · `page_view`, l'événement **du contrat**, commun au web, à Android et à
///    iOS. C'est le premier étage du tunnel ; il doit porter le même nom
///    partout, sinon le tunnel ne se lit pas d'une plateforme à l'autre.
///  · `screen_view`, l'événement **natif de Firebase**, qui alimente les
///    rapports « Écrans » et les mesures d'engagement de la console. Il porte un
///    autre nom : le conserver ne double donc aucun comptage.
///
/// Le paramètre `page_view` du mobile est un nom d'écran, celui du web un
/// chemin d'URL — c'est la seule divergence prévue par le contrat, et elle ne
/// porte que sur les paramètres, jamais sur le nom de l'événement.
///
/// ⚠️ **Pourquoi un observateur et pas un appel dans chaque `build`** : un
/// `build` est rejoué à chaque changement d'état — clavier, thème, réponse
/// réseau, notification. Un `page_view` posé là partirait dix fois par écran.
/// L'observateur, lui, ne parle qu'aux transitions de navigation réelles.
class LiliaAnalyticsObserver extends NavigatorObserver {
  LiliaAnalyticsObserver({
    required LiliaAnalytics analytics,
    FirebaseAnalytics? firebase,
  }) : _analytics = analytics,
       _firebase = firebase;

  final LiliaAnalytics _analytics;
  final FirebaseAnalytics? _firebase;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _send(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _send(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Un retour arrière **est** une nouvelle consultation de l'écran précédent :
    // le client le regarde à nouveau. On l'émet donc, et c'est la fenêtre
    // d'absorption de `LiliaAnalytics` qui écarte les rejeux immédiats.
    _send(previousRoute);
  }

  void _send(Route<dynamic>? route) {
    final name = _nameOf(route);
    if (name == null) return;

    _analytics.track(AnalyticsEvents.pageView, {
      AnalyticsParams.screenName: name,
    });

    _firebase
        ?.logScreenView(screenName: name, screenClass: name)
        .catchError((_) {});
  }

  /// Nom de l'écran, tel que déclaré dans `AppRoutes`.
  ///
  /// Les routes anonymes (modales, feuilles de dialogue poussées sans nom) sont
  /// ignorées : les compter ferait apparaître autant de « pages » que de
  /// confirmations affichées, et gonflerait le premier étage du tunnel.
  String? _nameOf(Route<dynamic>? route) {
    if (route is! PageRoute) return null;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return null;
    return name;
  }
}
