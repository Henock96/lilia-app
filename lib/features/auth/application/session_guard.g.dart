// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_guard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ce qu'il advient d'une session que le serveur n'accepte plus.
///
/// ## Ce qui se passait avant
///
/// `AuthInterceptor` tente **un** rafraîchissement du jeton Firebase sur 401,
/// rejoue la requête, puis laisse l'erreur passer. `ErrorInterceptor` la
/// marque `ApiErrorKind.unauthorized`. Deux dépôts lisaient ce `kind` pour des
/// replis locaux (panier, avis) — mais **personne ne s'occupait de la session
/// elle-même**.
///
/// Résultat pour un compte supprimé côté serveur ou un jeton révoqué : le
/// client restait « connecté » côté Firebase, face à des écrans vides et des
/// messages génériques, indéfiniment. Aucun écran ne pouvait rattraper cet
/// état, et rien ne lui disait de se reconnecter.
///
/// ## Les quatre pièges, et comment ils sont tenus
///
/// 1. **Boucle de déconnexion.** `signOut()` appelle lui-même le serveur
///    (`DELETE /notifications/token`), qui peut répondre 401 à son tour. Le
///    drapeau [_deconnexionEnCours] absorbe ce second passage.
/// 2. **Déconnexions concurrentes.** Un écran lance volontiers trois requêtes
///    en parallèle ; elles échouent toutes les trois. Le drapeau est posé
///    avant le premier `await`, donc avant que la deuxième n'arrive.
/// 3. **Messages en double.** L'annonce est faite une seule fois, au même
///    endroit et sous la même garde.
/// 4. **Destruction inutile de données locales.** Rien n'est effacé ici : on
///    réutilise `AuthController.signOut()`, qui sait déjà quoi invalider.
///
/// ## Pourquoi le drapeau se réarme tout seul
///
/// Il ne couvre **que la durée de la déconnexion**, et non « le reste de la
/// session ». C'est suffisant, et c'est plus sûr : une fois `signOut()`
/// terminé, `currentUser` vaut `null`, et le test de session vide arrête déjà
/// tout 401 ultérieur. Une reconnexion retrouve donc une garde armée sans
/// qu'on ait à observer quoi que ce soit — pas de `ref.listen` dont il
/// faudrait garantir l'installation avant le premier appel réseau.

@ProviderFor(SessionGuard)
final sessionGuardProvider = SessionGuardProvider._();

/// Ce qu'il advient d'une session que le serveur n'accepte plus.
///
/// ## Ce qui se passait avant
///
/// `AuthInterceptor` tente **un** rafraîchissement du jeton Firebase sur 401,
/// rejoue la requête, puis laisse l'erreur passer. `ErrorInterceptor` la
/// marque `ApiErrorKind.unauthorized`. Deux dépôts lisaient ce `kind` pour des
/// replis locaux (panier, avis) — mais **personne ne s'occupait de la session
/// elle-même**.
///
/// Résultat pour un compte supprimé côté serveur ou un jeton révoqué : le
/// client restait « connecté » côté Firebase, face à des écrans vides et des
/// messages génériques, indéfiniment. Aucun écran ne pouvait rattraper cet
/// état, et rien ne lui disait de se reconnecter.
///
/// ## Les quatre pièges, et comment ils sont tenus
///
/// 1. **Boucle de déconnexion.** `signOut()` appelle lui-même le serveur
///    (`DELETE /notifications/token`), qui peut répondre 401 à son tour. Le
///    drapeau [_deconnexionEnCours] absorbe ce second passage.
/// 2. **Déconnexions concurrentes.** Un écran lance volontiers trois requêtes
///    en parallèle ; elles échouent toutes les trois. Le drapeau est posé
///    avant le premier `await`, donc avant que la deuxième n'arrive.
/// 3. **Messages en double.** L'annonce est faite une seule fois, au même
///    endroit et sous la même garde.
/// 4. **Destruction inutile de données locales.** Rien n'est effacé ici : on
///    réutilise `AuthController.signOut()`, qui sait déjà quoi invalider.
///
/// ## Pourquoi le drapeau se réarme tout seul
///
/// Il ne couvre **que la durée de la déconnexion**, et non « le reste de la
/// session ». C'est suffisant, et c'est plus sûr : une fois `signOut()`
/// terminé, `currentUser` vaut `null`, et le test de session vide arrête déjà
/// tout 401 ultérieur. Une reconnexion retrouve donc une garde armée sans
/// qu'on ait à observer quoi que ce soit — pas de `ref.listen` dont il
/// faudrait garantir l'installation avant le premier appel réseau.
final class SessionGuardProvider extends $NotifierProvider<SessionGuard, void> {
  /// Ce qu'il advient d'une session que le serveur n'accepte plus.
  ///
  /// ## Ce qui se passait avant
  ///
  /// `AuthInterceptor` tente **un** rafraîchissement du jeton Firebase sur 401,
  /// rejoue la requête, puis laisse l'erreur passer. `ErrorInterceptor` la
  /// marque `ApiErrorKind.unauthorized`. Deux dépôts lisaient ce `kind` pour des
  /// replis locaux (panier, avis) — mais **personne ne s'occupait de la session
  /// elle-même**.
  ///
  /// Résultat pour un compte supprimé côté serveur ou un jeton révoqué : le
  /// client restait « connecté » côté Firebase, face à des écrans vides et des
  /// messages génériques, indéfiniment. Aucun écran ne pouvait rattraper cet
  /// état, et rien ne lui disait de se reconnecter.
  ///
  /// ## Les quatre pièges, et comment ils sont tenus
  ///
  /// 1. **Boucle de déconnexion.** `signOut()` appelle lui-même le serveur
  ///    (`DELETE /notifications/token`), qui peut répondre 401 à son tour. Le
  ///    drapeau [_deconnexionEnCours] absorbe ce second passage.
  /// 2. **Déconnexions concurrentes.** Un écran lance volontiers trois requêtes
  ///    en parallèle ; elles échouent toutes les trois. Le drapeau est posé
  ///    avant le premier `await`, donc avant que la deuxième n'arrive.
  /// 3. **Messages en double.** L'annonce est faite une seule fois, au même
  ///    endroit et sous la même garde.
  /// 4. **Destruction inutile de données locales.** Rien n'est effacé ici : on
  ///    réutilise `AuthController.signOut()`, qui sait déjà quoi invalider.
  ///
  /// ## Pourquoi le drapeau se réarme tout seul
  ///
  /// Il ne couvre **que la durée de la déconnexion**, et non « le reste de la
  /// session ». C'est suffisant, et c'est plus sûr : une fois `signOut()`
  /// terminé, `currentUser` vaut `null`, et le test de session vide arrête déjà
  /// tout 401 ultérieur. Une reconnexion retrouve donc une garde armée sans
  /// qu'on ait à observer quoi que ce soit — pas de `ref.listen` dont il
  /// faudrait garantir l'installation avant le premier appel réseau.
  SessionGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionGuardHash();

  @$internal
  @override
  SessionGuard create() => SessionGuard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$sessionGuardHash() => r'33b439868ca022d09b552467ac486d465a53474c';

/// Ce qu'il advient d'une session que le serveur n'accepte plus.
///
/// ## Ce qui se passait avant
///
/// `AuthInterceptor` tente **un** rafraîchissement du jeton Firebase sur 401,
/// rejoue la requête, puis laisse l'erreur passer. `ErrorInterceptor` la
/// marque `ApiErrorKind.unauthorized`. Deux dépôts lisaient ce `kind` pour des
/// replis locaux (panier, avis) — mais **personne ne s'occupait de la session
/// elle-même**.
///
/// Résultat pour un compte supprimé côté serveur ou un jeton révoqué : le
/// client restait « connecté » côté Firebase, face à des écrans vides et des
/// messages génériques, indéfiniment. Aucun écran ne pouvait rattraper cet
/// état, et rien ne lui disait de se reconnecter.
///
/// ## Les quatre pièges, et comment ils sont tenus
///
/// 1. **Boucle de déconnexion.** `signOut()` appelle lui-même le serveur
///    (`DELETE /notifications/token`), qui peut répondre 401 à son tour. Le
///    drapeau [_deconnexionEnCours] absorbe ce second passage.
/// 2. **Déconnexions concurrentes.** Un écran lance volontiers trois requêtes
///    en parallèle ; elles échouent toutes les trois. Le drapeau est posé
///    avant le premier `await`, donc avant que la deuxième n'arrive.
/// 3. **Messages en double.** L'annonce est faite une seule fois, au même
///    endroit et sous la même garde.
/// 4. **Destruction inutile de données locales.** Rien n'est effacé ici : on
///    réutilise `AuthController.signOut()`, qui sait déjà quoi invalider.
///
/// ## Pourquoi le drapeau se réarme tout seul
///
/// Il ne couvre **que la durée de la déconnexion**, et non « le reste de la
/// session ». C'est suffisant, et c'est plus sûr : une fois `signOut()`
/// terminé, `currentUser` vaut `null`, et le test de session vide arrête déjà
/// tout 401 ultérieur. Une reconnexion retrouve donc une garde armée sans
/// qu'on ait à observer quoi que ce soit — pas de `ref.listen` dont il
/// faudrait garantir l'installation avant le premier appel réseau.

abstract class _$SessionGuard extends $Notifier<void> {
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
