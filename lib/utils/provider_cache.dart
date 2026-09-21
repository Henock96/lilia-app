import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_cache.g.dart';

/// Durée de vie des listes du catalogue en cache.
///
/// Même valeur et même raisonnement que `kMenuCacheTtl` (la carte d'un
/// vendeur) : au-delà de cinq minutes, `isOpen`, la disponibilité et les prix
/// deviennent des affirmations que le serveur ne soutient plus.
const Duration kCatalogCacheTtl = Duration(minutes: 5);

/// Garde la valeur d'un provider `autoDispose` pendant [duree], même sans
/// auditeur.
///
/// ## Le problème qu'il résout
///
/// Un provider `@riverpod` est éliminé dès que son dernier auditeur disparaît.
/// Or un écran qui **part** est exactement cela : quitter l'accueil pour la
/// connexion détruit `HomeScreen`, donc ses quatre listes, donc au retour tout
/// est redemandé au serveur — quatre appels, sur la 4G de Brazzaville, pour
/// afficher ce qui était à l'écran dix secondes plus tôt.
///
/// Ce n'est pas propre à l'écran de connexion : la coque à onglets quitte
/// l'arbre chaque fois qu'un emplacement de premier niveau la remplace.
///
/// ## Pourquoi une durée, et pas `keepAlive: true`
///
/// `keepAlive: true` sans expiration fige la donnée pour toute la vie de
/// l'application : le client qui ouvre la boutique le matin et y revient
/// l'après-midi verrait les prix et les horaires du matin, sans que rien à
/// l'écran ne le suggère. Le checkout, lui, lirait les vrais prix — l'écart
/// n'apparaîtrait qu'au moment de payer. C'est le défaut qui avait déjà été
/// corrigé sur la carte d'un vendeur ; ce fichier généralise la correction.
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.
void cachePendant(Ref ref, Duration duree) {
  final link = ref.keepAlive();
  final timer = Timer(duree, link.close);
  ref.onDispose(timer.cancel);
}

/// Horodatage qui ne change qu'aux reprises **tardives** de l'application.
///
/// ## Pourquoi la durée de vie ne suffit pas
///
/// Un téléphone posé deux heures avec l'écran de la boutique ouvert laisse le
/// widget monté : le minuteur aura bien relâché le lien, mais rien ne
/// redemandera la donnée tant que l'utilisateur ne navigue pas. Or reprendre
/// l'application est **exactement** le moment où il regarde à nouveau le menu.
///
/// ## Pourquoi « tardives » et pas « toutes »
///
/// Publier un horodatage à chaque reprise rechargerait la carte après un simple
/// aller-retour vers les notifications. On ne publie donc que si l'écart dépasse
/// [kCatalogCacheTtl] — en dessous, la donnée est encore bonne, et Riverpod ne voit
/// aucun changement de valeur, donc ne reconstruit rien.
@Riverpod(keepAlive: true)
class StaleForegroundStamp extends _$StaleForegroundStamp
    with WidgetsBindingObserver {
  @override
  DateTime build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    // `this.state` — le paramètre du callback masque le champ du notifier.
    if (now.difference(this.state) >= kCatalogCacheTtl) this.state = now;
  }
}
