import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'build_error_state.dart';
import 'build_loading_state.dart';

/// **Un écran de détail se reconstruit depuis son identifiant, jamais depuis
/// l'objet qu'on lui a passé.**
///
/// ## Ce que ce widget remplace
///
/// Six routes dépendaient de `state.extra` — `productDetail`, `menuDetail`,
/// `favoriteDetail`, `reviews`, `writeReview`, `checkout`. go_router restaure
/// l'**emplacement** après une mort de processus (mémoire basse, « Ne pas
/// conserver les activités », retour d'un appel), **jamais** la charge utile.
/// Le client revenait sur `NotFoundScreen`.
///
/// `productDetail` a été corrigé le premier, et son corps — « si l'objet est
/// là, rendre ; sinon charger, avec le bon traitement du chargement en
/// erreur » — allait être recopié trois fois. Recopié trois fois, il aurait
/// divergé trois fois : c'est précisément ce qui est arrivé à la référence de
/// commande (`order_reference.dart`).
///
/// ## Le piège qu'il encapsule
///
/// `isLoading && !hasError`, et non `isLoading` seul. Riverpod 3 **relance**
/// automatiquement un provider en échec, avec un backoff : entre deux
/// tentatives il repasse par le chargement **tout en portant son erreur**. Un
/// écran qui ne regarde que `isLoading` affiche un indicateur perpétuel au
/// lieu de dire ce qui ne va pas.
///
/// ## L'objet en `extra` reste accepté
///
/// C'est le chemin rapide, sans aller-retour, quand on arrive d'une liste qui
/// le détient déjà. Il n'est simplement plus **nécessaire**.
class ResolutionParIdentifiant<T> extends ConsumerWidget {
  const ResolutionParIdentifiant({
    super.key,
    required this.dejaLa,
    required this.charger,
    required this.onRetry,
    required this.introuvable,
    required this.rendu,
  });

  /// L'objet passé en `extra`, s'il y en avait un.
  final T? dejaLa;

  /// La lecture par identifiant, pour quand il n'y en avait pas.
  ///
  /// ⚠️ Une **fonction**, et non un `AsyncValue` déjà calculé. Un argument
  /// est évalué au site d'appel : passer `ref.watch(...)` directement
  /// observerait le provider — donc déclencherait la requête — même quand
  /// l'objet est déjà là. Tout l'intérêt de garder `extra` est précisément de
  /// ne rien coûter. `product_route_survives_restart_test` le vérifie.
  final AsyncValue<T> Function(WidgetRef ref) charger;

  final VoidCallback onRetry;

  /// Ce qu'on dit quand ni l'un ni l'autre n'a abouti.
  final String introuvable;

  final Widget Function(T valeur) rendu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immediat = dejaLa;
    if (immediat != null) return rendu(immediat);

    final source = charger(ref);
    final charge = source.value;
    if (charge != null) return rendu(charge);

    if (source.isLoading && !source.hasError) {
      return const Scaffold(body: BuildLoadingState());
    }
    return Scaffold(
      appBar: AppBar(),
      body: BuildErrorState(source.error ?? introuvable, onRetry: onRetry),
    );
  }
}
