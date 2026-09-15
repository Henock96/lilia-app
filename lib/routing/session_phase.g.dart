// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_phase.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// La phase courante, dérivée des deux seules sources qui la déterminent.
///
/// `keepAlive` : le routeur s'y abonne pour la vie de l'application.
///
/// Deux replis volontaires, tous deux hérités du comportement précédent et
/// conservés parce qu'ils vont dans le bon sens :
/// * une **erreur** de lecture de l'onboarding (SharedPreferences indisponible)
///   vaut « déjà fait » — une panne de stockage local ne doit pas coincer un
///   client dans un carrousel de présentation ;
/// * une **erreur** du flux Firebase vaut « déconnecté » — c'est le seul état
///   sûr, et il mène à l'écran de connexion, d'où l'on peut agir.
///
/// Ce qui compte : une erreur **résout** la phase, elle ne la laisse jamais en
/// [SessionPhase.bootstrapping]. Un écran de démarrage dont on ne sort pas
/// serait pire que le flash qu'il remplace.

@ProviderFor(sessionPhase)
final sessionPhaseProvider = SessionPhaseProvider._();

/// La phase courante, dérivée des deux seules sources qui la déterminent.
///
/// `keepAlive` : le routeur s'y abonne pour la vie de l'application.
///
/// Deux replis volontaires, tous deux hérités du comportement précédent et
/// conservés parce qu'ils vont dans le bon sens :
/// * une **erreur** de lecture de l'onboarding (SharedPreferences indisponible)
///   vaut « déjà fait » — une panne de stockage local ne doit pas coincer un
///   client dans un carrousel de présentation ;
/// * une **erreur** du flux Firebase vaut « déconnecté » — c'est le seul état
///   sûr, et il mène à l'écran de connexion, d'où l'on peut agir.
///
/// Ce qui compte : une erreur **résout** la phase, elle ne la laisse jamais en
/// [SessionPhase.bootstrapping]. Un écran de démarrage dont on ne sort pas
/// serait pire que le flash qu'il remplace.

final class SessionPhaseProvider
    extends $FunctionalProvider<SessionPhase, SessionPhase, SessionPhase>
    with $Provider<SessionPhase> {
  /// La phase courante, dérivée des deux seules sources qui la déterminent.
  ///
  /// `keepAlive` : le routeur s'y abonne pour la vie de l'application.
  ///
  /// Deux replis volontaires, tous deux hérités du comportement précédent et
  /// conservés parce qu'ils vont dans le bon sens :
  /// * une **erreur** de lecture de l'onboarding (SharedPreferences indisponible)
  ///   vaut « déjà fait » — une panne de stockage local ne doit pas coincer un
  ///   client dans un carrousel de présentation ;
  /// * une **erreur** du flux Firebase vaut « déconnecté » — c'est le seul état
  ///   sûr, et il mène à l'écran de connexion, d'où l'on peut agir.
  ///
  /// Ce qui compte : une erreur **résout** la phase, elle ne la laisse jamais en
  /// [SessionPhase.bootstrapping]. Un écran de démarrage dont on ne sort pas
  /// serait pire que le flash qu'il remplace.
  SessionPhaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionPhaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionPhaseHash();

  @$internal
  @override
  $ProviderElement<SessionPhase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionPhase create(Ref ref) {
    return sessionPhase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPhase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPhase>(value),
    );
  }
}

String _$sessionPhaseHash() => r'58966b08667b045a377adff2e29e1999a55ef0cd';
