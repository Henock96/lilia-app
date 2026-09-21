// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(StaleForegroundStamp)
final staleForegroundStampProvider = StaleForegroundStampProvider._();

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
final class StaleForegroundStampProvider
    extends $NotifierProvider<StaleForegroundStamp, DateTime> {
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
  StaleForegroundStampProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'staleForegroundStampProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$staleForegroundStampHash();

  @$internal
  @override
  StaleForegroundStamp create() => StaleForegroundStamp();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$staleForegroundStampHash() =>
    r'd328aa9b7d61d49ff661669dd7823968bbc664d8';

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

abstract class _$StaleForegroundStamp extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
