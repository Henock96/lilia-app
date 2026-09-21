// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_effects.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// **Ce qui se produit quand une session s'ouvre, et quand elle se ferme.**
///
/// ## Le défaut que ce fichier corrige
///
/// Ces effets vivaient dans `AuthController.build()`, dans une écoute posée à
/// la main sur `authStateChanges()`. Le raisonnement était juste — la reprise
/// du panier et l'enregistrement du jeton appartiennent à la **transition de
/// session**, pas à un écran, parce que la connexion peut venir de six
/// endroits et que chacun oublierait tôt ou tard de le faire.
///
/// Mais `authControllerProvider` n'était observé par **aucun** écran au
/// démarrage : le seul `ref.watch` de toute l'application est dans
/// `edit_profile_page.dart`. Les providers Riverpod étant paresseux,
/// `AuthController.build()` ne s'exécutait qu'au premier
/// `ref.read(...notifier)` — c'est-à-dire à la déconnexion, à la suppression
/// de compte, ou sur un 401. **Jamais à la connexion.**
///
/// Conséquences mesurées :
///
/// * le panier composé sans compte n'était jamais versé dans le panier du
///   compte : `POST /orders/checkout` répondait « panier vide » à un client
///   dont l'écran affichait un panier plein ;
/// * aucun jeton FCM n'était enregistré pour une session ouverte en cours
///   d'exécution — la première commande de chaque nouvel utilisateur se
///   déroulait sans une seule notification.
///
/// ## Aucun nouvel abonnement Firebase
///
/// C'est la contrainte qui décide de la forme. L'application compte **un**
/// abonnement à `authStateChanges()` qui soit réellement actif :
/// `authStateChangeProvider`, observé par `sessionPhaseProvider`, lui-même
/// observé par `routerProvider`, lui-même observé par `MyApp`. Ce provider est
/// donc vivant pour toute la durée de l'application, et Riverpod partage son
/// unique souscription entre tous ses auditeurs.
///
/// ```text
/// FirebaseAuth.authStateChanges()        ← UNE souscription
///        │
///        └─ authStateChangeProvider      (keepAlive)
///             ├─ sessionPhaseProvider → routerProvider → MyApp
///             └─ sessionEffectsProvider → MyApp          ← ce fichier
/// ```
///
/// `AuthController` s'y branchait **deux fois** (une écoute manuelle *et* le
/// `Stream` rendu, que Riverpod souscrit à son tour). Ce doublon a disparu :
/// le contrôleur ne raconte plus que la session, conformément à son propre
/// en-tête.
///
/// ## Déduplication
///
/// Un flux d'authentification réémet volontiers la même session (réabonnement,
/// rafraîchissement interne). Seul un **changement d'identifiant** déclenche un
/// effet, et [_amorce] distingue « première émission » de « aucun changement ».
///
/// | Transition | Effet |
/// |---|---|
/// | `null → A` (connexion, inscription) | ouverture |
/// | `∅ → A` (session restaurée au démarrage) | ouverture |
/// | `A → A` (réémission) | **rien** |
/// | `A → null` (déconnexion) | fermeture |
/// | `A → null → B` (changement de compte) | fermeture puis ouverture |
/// | `∅ → null` (démarrage sans session) | **rien** |

@ProviderFor(SessionEffects)
final sessionEffectsProvider = SessionEffectsProvider._();

/// **Ce qui se produit quand une session s'ouvre, et quand elle se ferme.**
///
/// ## Le défaut que ce fichier corrige
///
/// Ces effets vivaient dans `AuthController.build()`, dans une écoute posée à
/// la main sur `authStateChanges()`. Le raisonnement était juste — la reprise
/// du panier et l'enregistrement du jeton appartiennent à la **transition de
/// session**, pas à un écran, parce que la connexion peut venir de six
/// endroits et que chacun oublierait tôt ou tard de le faire.
///
/// Mais `authControllerProvider` n'était observé par **aucun** écran au
/// démarrage : le seul `ref.watch` de toute l'application est dans
/// `edit_profile_page.dart`. Les providers Riverpod étant paresseux,
/// `AuthController.build()` ne s'exécutait qu'au premier
/// `ref.read(...notifier)` — c'est-à-dire à la déconnexion, à la suppression
/// de compte, ou sur un 401. **Jamais à la connexion.**
///
/// Conséquences mesurées :
///
/// * le panier composé sans compte n'était jamais versé dans le panier du
///   compte : `POST /orders/checkout` répondait « panier vide » à un client
///   dont l'écran affichait un panier plein ;
/// * aucun jeton FCM n'était enregistré pour une session ouverte en cours
///   d'exécution — la première commande de chaque nouvel utilisateur se
///   déroulait sans une seule notification.
///
/// ## Aucun nouvel abonnement Firebase
///
/// C'est la contrainte qui décide de la forme. L'application compte **un**
/// abonnement à `authStateChanges()` qui soit réellement actif :
/// `authStateChangeProvider`, observé par `sessionPhaseProvider`, lui-même
/// observé par `routerProvider`, lui-même observé par `MyApp`. Ce provider est
/// donc vivant pour toute la durée de l'application, et Riverpod partage son
/// unique souscription entre tous ses auditeurs.
///
/// ```text
/// FirebaseAuth.authStateChanges()        ← UNE souscription
///        │
///        └─ authStateChangeProvider      (keepAlive)
///             ├─ sessionPhaseProvider → routerProvider → MyApp
///             └─ sessionEffectsProvider → MyApp          ← ce fichier
/// ```
///
/// `AuthController` s'y branchait **deux fois** (une écoute manuelle *et* le
/// `Stream` rendu, que Riverpod souscrit à son tour). Ce doublon a disparu :
/// le contrôleur ne raconte plus que la session, conformément à son propre
/// en-tête.
///
/// ## Déduplication
///
/// Un flux d'authentification réémet volontiers la même session (réabonnement,
/// rafraîchissement interne). Seul un **changement d'identifiant** déclenche un
/// effet, et [_amorce] distingue « première émission » de « aucun changement ».
///
/// | Transition | Effet |
/// |---|---|
/// | `null → A` (connexion, inscription) | ouverture |
/// | `∅ → A` (session restaurée au démarrage) | ouverture |
/// | `A → A` (réémission) | **rien** |
/// | `A → null` (déconnexion) | fermeture |
/// | `A → null → B` (changement de compte) | fermeture puis ouverture |
/// | `∅ → null` (démarrage sans session) | **rien** |
final class SessionEffectsProvider
    extends $NotifierProvider<SessionEffects, void> {
  /// **Ce qui se produit quand une session s'ouvre, et quand elle se ferme.**
  ///
  /// ## Le défaut que ce fichier corrige
  ///
  /// Ces effets vivaient dans `AuthController.build()`, dans une écoute posée à
  /// la main sur `authStateChanges()`. Le raisonnement était juste — la reprise
  /// du panier et l'enregistrement du jeton appartiennent à la **transition de
  /// session**, pas à un écran, parce que la connexion peut venir de six
  /// endroits et que chacun oublierait tôt ou tard de le faire.
  ///
  /// Mais `authControllerProvider` n'était observé par **aucun** écran au
  /// démarrage : le seul `ref.watch` de toute l'application est dans
  /// `edit_profile_page.dart`. Les providers Riverpod étant paresseux,
  /// `AuthController.build()` ne s'exécutait qu'au premier
  /// `ref.read(...notifier)` — c'est-à-dire à la déconnexion, à la suppression
  /// de compte, ou sur un 401. **Jamais à la connexion.**
  ///
  /// Conséquences mesurées :
  ///
  /// * le panier composé sans compte n'était jamais versé dans le panier du
  ///   compte : `POST /orders/checkout` répondait « panier vide » à un client
  ///   dont l'écran affichait un panier plein ;
  /// * aucun jeton FCM n'était enregistré pour une session ouverte en cours
  ///   d'exécution — la première commande de chaque nouvel utilisateur se
  ///   déroulait sans une seule notification.
  ///
  /// ## Aucun nouvel abonnement Firebase
  ///
  /// C'est la contrainte qui décide de la forme. L'application compte **un**
  /// abonnement à `authStateChanges()` qui soit réellement actif :
  /// `authStateChangeProvider`, observé par `sessionPhaseProvider`, lui-même
  /// observé par `routerProvider`, lui-même observé par `MyApp`. Ce provider est
  /// donc vivant pour toute la durée de l'application, et Riverpod partage son
  /// unique souscription entre tous ses auditeurs.
  ///
  /// ```text
  /// FirebaseAuth.authStateChanges()        ← UNE souscription
  ///        │
  ///        └─ authStateChangeProvider      (keepAlive)
  ///             ├─ sessionPhaseProvider → routerProvider → MyApp
  ///             └─ sessionEffectsProvider → MyApp          ← ce fichier
  /// ```
  ///
  /// `AuthController` s'y branchait **deux fois** (une écoute manuelle *et* le
  /// `Stream` rendu, que Riverpod souscrit à son tour). Ce doublon a disparu :
  /// le contrôleur ne raconte plus que la session, conformément à son propre
  /// en-tête.
  ///
  /// ## Déduplication
  ///
  /// Un flux d'authentification réémet volontiers la même session (réabonnement,
  /// rafraîchissement interne). Seul un **changement d'identifiant** déclenche un
  /// effet, et [_amorce] distingue « première émission » de « aucun changement ».
  ///
  /// | Transition | Effet |
  /// |---|---|
  /// | `null → A` (connexion, inscription) | ouverture |
  /// | `∅ → A` (session restaurée au démarrage) | ouverture |
  /// | `A → A` (réémission) | **rien** |
  /// | `A → null` (déconnexion) | fermeture |
  /// | `A → null → B` (changement de compte) | fermeture puis ouverture |
  /// | `∅ → null` (démarrage sans session) | **rien** |
  SessionEffectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionEffectsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionEffectsHash();

  @$internal
  @override
  SessionEffects create() => SessionEffects();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$sessionEffectsHash() => r'dfcd237f21cfaa5b5ce3894d8a05561602d9cd19';

/// **Ce qui se produit quand une session s'ouvre, et quand elle se ferme.**
///
/// ## Le défaut que ce fichier corrige
///
/// Ces effets vivaient dans `AuthController.build()`, dans une écoute posée à
/// la main sur `authStateChanges()`. Le raisonnement était juste — la reprise
/// du panier et l'enregistrement du jeton appartiennent à la **transition de
/// session**, pas à un écran, parce que la connexion peut venir de six
/// endroits et que chacun oublierait tôt ou tard de le faire.
///
/// Mais `authControllerProvider` n'était observé par **aucun** écran au
/// démarrage : le seul `ref.watch` de toute l'application est dans
/// `edit_profile_page.dart`. Les providers Riverpod étant paresseux,
/// `AuthController.build()` ne s'exécutait qu'au premier
/// `ref.read(...notifier)` — c'est-à-dire à la déconnexion, à la suppression
/// de compte, ou sur un 401. **Jamais à la connexion.**
///
/// Conséquences mesurées :
///
/// * le panier composé sans compte n'était jamais versé dans le panier du
///   compte : `POST /orders/checkout` répondait « panier vide » à un client
///   dont l'écran affichait un panier plein ;
/// * aucun jeton FCM n'était enregistré pour une session ouverte en cours
///   d'exécution — la première commande de chaque nouvel utilisateur se
///   déroulait sans une seule notification.
///
/// ## Aucun nouvel abonnement Firebase
///
/// C'est la contrainte qui décide de la forme. L'application compte **un**
/// abonnement à `authStateChanges()` qui soit réellement actif :
/// `authStateChangeProvider`, observé par `sessionPhaseProvider`, lui-même
/// observé par `routerProvider`, lui-même observé par `MyApp`. Ce provider est
/// donc vivant pour toute la durée de l'application, et Riverpod partage son
/// unique souscription entre tous ses auditeurs.
///
/// ```text
/// FirebaseAuth.authStateChanges()        ← UNE souscription
///        │
///        └─ authStateChangeProvider      (keepAlive)
///             ├─ sessionPhaseProvider → routerProvider → MyApp
///             └─ sessionEffectsProvider → MyApp          ← ce fichier
/// ```
///
/// `AuthController` s'y branchait **deux fois** (une écoute manuelle *et* le
/// `Stream` rendu, que Riverpod souscrit à son tour). Ce doublon a disparu :
/// le contrôleur ne raconte plus que la session, conformément à son propre
/// en-tête.
///
/// ## Déduplication
///
/// Un flux d'authentification réémet volontiers la même session (réabonnement,
/// rafraîchissement interne). Seul un **changement d'identifiant** déclenche un
/// effet, et [_amorce] distingue « première émission » de « aucun changement ».
///
/// | Transition | Effet |
/// |---|---|
/// | `null → A` (connexion, inscription) | ouverture |
/// | `∅ → A` (session restaurée au démarrage) | ouverture |
/// | `A → A` (réémission) | **rien** |
/// | `A → null` (déconnexion) | fermeture |
/// | `A → null → B` (changement de compte) | fermeture puis ouverture |
/// | `∅ → null` (démarrage sans session) | **rien** |

abstract class _$SessionEffects extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
